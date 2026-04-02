package main

import (
	"encoding/hex"
	"flag"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"go.bug.st/serial"

	"winetap/internal/integration/cfru5102"
)

func main() {
	port := flag.String("port", "/dev/ttyUSB0", "serial port device path")
	logLevel := flag.String("log-level", "info", "log level: debug, info, warn, error")
	logFormat := flag.String("log-format", "text", "log format: text, json")
	flag.Parse()

	logger := setupLogger(*logLevel, *logFormat)

	mode := &serial.Mode{
		BaudRate: 57600,
		DataBits: 8,
		Parity:   serial.NoParity,
		StopBits: serial.OneStopBit,
	}
	p, err := serial.Open(*port, mode)
	if err != nil {
		logger.Error("open serial port", "port", *port, "error", err)
		os.Exit(1)
	}
	defer p.Close()

	logger.Debug("serial port open", "port", *port, "baud", 57600)

	r := cfru5102.New(p, 0x00, logger)

	info, err := r.GetReaderInformation(cfru5102.GetReaderInformationParams{})
	if err != nil {
		logger.Error("GetReaderInformation failed", "error", err)
		os.Exit(1)
	}

	logger.Info("reader info",
		"firmware", fmt.Sprintf("%d.%d", info.VersionMajor, info.VersionMinor),
		"type", fmt.Sprintf("0x%02X", info.Type),
		"protocols", info.SupportedProtocols.String(),
		"max_freq_mhz", info.MaxFreq.MHz(),
		"min_freq_mhz", info.MinFreq.MHz(),
		"power_dBm", info.Power,
		"scan_time_ms", int(info.ScanTime)*100,
	)
	r.SetScanTime(cfru5102.SetScanTimeParams{
		ScanTime: 3, // 300 ms
	})

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)

	ticker := time.NewTicker(time.Millisecond * 375) // slightly longer than scan time to avoid overlap
	defer ticker.Stop()

	logger.Info("starting inventory loop — Ctrl+C to stop")

	for {
		select {
		case <-sig:
			logger.Info("stopped")
			return
		case <-ticker.C:
		}

		result, err := r.Inventory(cfru5102.InventoryParams{})
		if err != nil {
			logger.Error("inventory error", "error", err)
			continue
		}

		logger.Info("inventory",
			"status", result.Status.String(),
			"count", len(result.EPCs),
		)
		for i, epc := range result.EPCs {
			logger.Info("tag", "index", i, "epc", hex.EncodeToString(epc))
		}
	}
}

func powerStr(p uint8) string {
	if p == 0 {
		return "unknown"
	}
	return fmt.Sprintf("%d dBm", p)
}

func setupLogger(level, format string) *slog.Logger {
	var l slog.Level
	switch strings.ToLower(level) {
	case "debug":
		l = slog.LevelDebug
	case "warn", "warning":
		l = slog.LevelWarn
	case "error":
		l = slog.LevelError
	default:
		l = slog.LevelInfo
	}
	opts := &slog.HandlerOptions{Level: l}
	var handler slog.Handler
	if strings.ToLower(format) == "json" {
		handler = slog.NewJSONHandler(os.Stderr, opts)
	} else {
		handler = slog.NewTextHandler(os.Stderr, opts)
	}
	return slog.New(handler)
}
