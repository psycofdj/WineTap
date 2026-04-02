package cfru5102

import (
	"context"
	"fmt"
	"io"
	"log/slog"
)

// Reader is a handle to a CF-RU5102 UHF RFID reader.
//
// All commands are synchronous: the caller sends a request and blocks until the
// full response has been received.  The reader processes one command at a time;
// sending a second command while the first is still executing causes the second
// to be discarded by the hardware.
type Reader struct {
	port   io.ReadWriter
	addr   byte
	logger *slog.Logger
}

// New creates a new Reader.
//
//   - port:   an open serial port (57600 8N1); callers retain ownership.
//   - addr:   reader address, default 0x00; 0xFF is the broadcast address.
//   - logger: used for debug-level frame traces (pass slog.Default() if you
//     don't need a custom logger).
func New(port io.ReadWriter, addr byte, logger *slog.Logger) *Reader {
	return &Reader{port: port, addr: addr, logger: logger}
}

// send writes a fully-assembled command frame to the port.
func (r *Reader) send(frame []byte) error {
	_, err := r.port.Write(frame)
	if err != nil {
		return fmt.Errorf("write: %w", err)
	}
	return nil
}

// recv reads one complete response frame from the port.
//
// The protocol guarantees that the first byte is Len, and that the total frame
// is Len+1 bytes.  We read the first byte to learn the size, then read the rest.
func (r *Reader) recv() ([]byte, error) {
	lenBuf := [1]byte{}
	if _, err := io.ReadFull(r.port, lenBuf[:]); err != nil {
		return nil, fmt.Errorf("reading Len byte: %w", err)
	}
	rest := make([]byte, lenBuf[0])
	if _, err := io.ReadFull(r.port, rest); err != nil {
		return nil, fmt.Errorf("reading frame body: %w", err)
	}
	return append(lenBuf[:], rest...), nil
}

// exchange sends a command frame and returns the parsed response.
// It logs the raw TX and RX bytes at Debug level with field-by-field annotations.
func (r *Reader) exchange(
	cmdFrame []byte,
	txFields []debugField,
	expectedCmd byte,
	rxFields func(raw []byte) []debugField,
) (response, error) {
	r.debugFrame("TX", cmdFrame, txFields)

	if err := r.send(cmdFrame); err != nil {
		return response{}, err
	}

	raw, err := r.recv()
	if err != nil {
		return response{}, err
	}

	r.debugFrame("RX", raw, rxFields(raw))

	return parseResponse(raw, expectedCmd)
}

// debugField describes one byte or multi-byte field in a frame for human-readable logging.
type debugField struct {
	offset int
	length int    // number of bytes this field spans
	name   string // short field name
	detail string // human description of the value
}

// debugFrame logs frame bytes at slog.LevelDebug.
// Each annotated field becomes one slog attribute keyed as "[offset] FieldName".
// Any byte not covered by a field annotation is logged as "[offset] unannotated".
func (r *Reader) debugFrame(direction string, frame []byte, fields []debugField) {
	if !r.logger.Enabled(context.Background(), slog.LevelDebug) {
		return
	}

	covered := make(map[int]bool)
	attrs := make([]any, 0, len(fields)+4)
	attrs = append(attrs, "size", fmt.Sprintf("%d", len(frame)))
	attrs = append(attrs, "frame", hexDump(frame, 0, len(frame)))

	for _, f := range fields {
		for i := range f.length {
			covered[f.offset+i] = true
		}
		attrs = append(attrs,
			fmt.Sprintf("Arg%d", f.offset),
			fmt.Sprintf("%s [%s] — %s", f.name, hexDump(frame, f.offset, f.length), f.detail),
		)
	}

	for i, b := range frame {
		if !covered[i] {
			attrs = append(attrs,
				fmt.Sprintf("Arg%d", i),
				fmt.Sprintf("unannotated: 0x%02X", b),
			)
		}
	}

	r.logger.Debug(direction, attrs...)
}

// hexDump returns a space-separated hex representation of length bytes starting
// at offset in frame, using "0x??" for out-of-bounds positions.
func hexDump(frame []byte, offset, length int) string {
	b := make([]byte, 0, length*5)
	for i := range length {
		if i > 0 {
			b = append(b, ' ')
		}
		if offset+i < len(frame) {
			b = fmt.Appendf(b, "%02X", frame[offset+i])
		} else {
			b = append(b, "??"...)
		}
	}
	return string(b)
}
