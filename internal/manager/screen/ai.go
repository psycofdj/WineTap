package screen

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/chromedp/chromedp"
)

// chatGPTQuery sends prompt to ChatGPT by driving a real Chrome browser that
// navigates to chatgpt.com, types the message in the chat UI, waits for the
// response, and scrapes the text — exactly like a human user would.
func chatGPTQuery(prompt string) (string, error) {
	opts := append(chromedp.DefaultExecAllocatorOptions[:],
		chromedp.Flag("headless", "new"),
		chromedp.Flag("disable-blink-features", "AutomationControlled"),
		chromedp.Flag("no-sandbox", true),
		chromedp.Flag("disable-dev-shm-usage", true),
		chromedp.UserAgent("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36"),
	)

	allocCtx, cancelAlloc := chromedp.NewExecAllocator(context.Background(), opts...)
	defer cancelAlloc()

	ctx, cancelCtx := chromedp.NewContext(allocCtx)
	defer cancelCtx()

	ctx, cancelTimeout := context.WithTimeout(ctx, 120*time.Second)
	defer cancelTimeout()

	slog.Debug("chatgpt: launching browser")

	if err := chromedp.Run(ctx,
		chromedp.Navigate("https://chatgpt.com/"),
		chromedp.Sleep(4*time.Second),
	); err != nil {
		return "", fmt.Errorf("navigate: %w", err)
	}

	slog.Debug("chatgpt: page loaded, dismissing cookie banner")

	// Dismiss cookie consent banner if present.
	_ = chromedp.Run(ctx, chromedp.Click(`button[data-testid="close-button"]`, chromedp.NodeVisible))
	// "Accept all" text button in the cookie banner.
	_ = chromedp.Run(ctx, chromedp.Evaluate(`
		(function(){
			for (const btn of document.querySelectorAll('button')) {
				if (btn.innerText.trim() === 'Accept all') { btn.click(); return true; }
			}
			return false;
		})()
	`, nil))
	_ = chromedp.Run(ctx, chromedp.Sleep(500*time.Millisecond))

	// Wait for the contenteditable prompt div to be in the DOM.
	if err := chromedp.Run(ctx, chromedp.WaitReady(`#prompt-textarea`, chromedp.ByID)); err != nil {
		return "", fmt.Errorf("wait for input: %w", err)
	}

	slog.Debug("chatgpt: input ready, injecting prompt")

	// Focus the contenteditable div and insert text via execCommand so React
	// picks up the change correctly.
	var ok bool
	if err := chromedp.Run(ctx, chromedp.Evaluate(fmt.Sprintf(`
		(function() {
			const el = document.getElementById('prompt-textarea');
			if (!el) return false;
			el.focus();
			document.execCommand('insertText', false, %q);
			return true;
		})()
	`, prompt), &ok)); err != nil || !ok {
		return "", fmt.Errorf("inject text into prompt: element not found or execCommand failed")
	}

	if err := chromedp.Run(ctx, chromedp.Sleep(400*time.Millisecond)); err != nil {
		return "", err
	}

	// Click the send button that appears after text is entered.
	const sendBtn = `button[data-testid="send-button"]`
	if err := chromedp.Run(ctx,
		chromedp.WaitVisible(sendBtn),
		chromedp.Click(sendBtn),
	); err != nil {
		// Fallback: press Enter.
		if err2 := chromedp.Run(ctx, chromedp.KeyEvent("\r")); err2 != nil {
			return "", fmt.Errorf("submit (send button: %v, enter: %v)", err, err2)
		}
	}

	slog.Debug("chatgpt: message sent, waiting for response")

	// Poll the last assistant message until its text has been stable for two
	// consecutive reads (500 ms apart).
	scrapeLastMsg := `
		(function() {
			const msgs = document.querySelectorAll('[data-message-author-role="assistant"]');
			if (!msgs.length) return '';
			const last = msgs[msgs.length - 1];
			const content = last.querySelector('.markdown, [class*="prose"]') || last;
			return content.innerText.trim();
		})()`

	var prev, result string
	for {
		if err := chromedp.Run(ctx, chromedp.Evaluate(scrapeLastMsg, &result)); err != nil {
			return "", fmt.Errorf("scrape response: %w", err)
		}
		if result != "" && result == prev {
			break
		}
		prev = result
		if err := chromedp.Run(ctx, chromedp.Sleep(2500*time.Millisecond)); err != nil {
			return "", err
		}
	}

	slog.Debug("chatgpt: scraped", "text", result)
	return result, nil
}

// extractJSONObject finds the first complete {...} object in s.
func extractJSONObject(s string) string {
	start := strings.Index(s, "{")
	end := strings.LastIndex(s, "}")
	if start < 0 || end <= start {
		return ""
	}
	return s[start : end+1]
}
