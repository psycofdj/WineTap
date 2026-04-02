// Package cfru5102 implements a driver for the Chafon CF-RU5102 UHF RFID reader.
//
// Communication: RS232/RS485, 57600 baud, 8N1, no parity.
// Protocol: host-initiated request/response over a simple framed binary protocol.
//
// Frame formats (from datasheet section 3):
//
//	Command:  [Len][Adr][Cmd][Data...][CRC_LSB][CRC_MSB]
//	          Len = len(Data) + 4  (excludes the Len byte itself)
//
//	Response: [Len][Adr][reCmd][Status][Data...][CRC_LSB][CRC_MSB]
//	          Len = len(Data) + 5  (excludes the Len byte itself)
//
// CRC: CRC-16/MCRF4XX — polynomial 0x8408, initial value 0xFFFF.
// Computed over all bytes starting from Len, excluding the two CRC bytes.
// Transmitted little-endian (LSB first).
package cfru5102

import (
	"fmt"
)

// crc16 computes CRC-16/MCRF4XX over buf.
// Polynomial 0x8408, initial value 0xFFFF (datasheet section 3, page 6).
func crc16(buf []byte) uint16 {
	crc := uint16(0xFFFF)
	for _, b := range buf {
		crc ^= uint16(b)
		for range 8 {
			if crc&0x0001 != 0 {
				crc = (crc >> 1) ^ 0x8408
			} else {
				crc >>= 1
			}
		}
	}
	return crc
}

// buildFrame assembles a command frame:
//
//	[Len][Adr][Cmd][data...][CRC_LSB][CRC_MSB]
func buildFrame(addr, cmd byte, data []byte) []byte {
	length := byte(len(data) + 4) // Adr + Cmd + CRC_LSB + CRC_MSB
	frame := make([]byte, 0, int(length)+1)
	frame = append(frame, length, addr, cmd)
	frame = append(frame, data...)
	crc := crc16(frame)
	frame = append(frame, byte(crc), byte(crc>>8))
	return frame
}

// response holds a parsed response frame.
type response struct {
	addr   byte
	cmd    byte
	status Status
	data   []byte
	raw    []byte // full raw frame including Len and CRC bytes
}

// parseResponse parses and validates a raw response frame.
// It verifies the CRC and checks that the echoed command matches expectedCmd.
func parseResponse(raw []byte, expectedCmd byte) (response, error) {
	if len(raw) < 5 {
		return response{}, fmt.Errorf("response too short: %d bytes", len(raw))
	}

	frameLen := int(raw[0])
	if len(raw) != frameLen+1 {
		return response{}, fmt.Errorf("length mismatch: Len byte=%d, actual frame body=%d", frameLen, len(raw)-1)
	}

	// Verify CRC: computed over everything except the two trailing CRC bytes.
	payload := raw[:len(raw)-2]
	crcLSB := raw[len(raw)-2]
	crcMSB := raw[len(raw)-1]
	got := crc16(payload)
	want := uint16(crcLSB) | uint16(crcMSB)<<8
	if got != want {
		return response{}, fmt.Errorf("CRC mismatch: computed 0x%04X, received 0x%04X", got, want)
	}

	addr := raw[1]
	rcmd := raw[2]
	status := Status(raw[3])

	if rcmd != expectedCmd {
		return response{}, fmt.Errorf("command echo mismatch: sent 0x%02X, got 0x%02X", expectedCmd, rcmd)
	}

	// Data[] sits between Status and the two CRC bytes.
	var data []byte
	if frameLen > 5 {
		data = raw[4 : len(raw)-2]
	}

	return response{
		addr:   addr,
		cmd:    rcmd,
		status: status,
		data:   data,
		raw:    raw,
	}, nil
}
