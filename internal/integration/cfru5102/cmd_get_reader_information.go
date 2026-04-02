package cfru5102

import (
	"fmt"
)

const cmdGetReaderInformation byte = 0x21

// Protocol is a bitmask of tag protocols supported by the reader (Tr_Type byte).
// Bit1 = ISO18000-6C (EPC C1G2), Bit0 = ISO18000-6B.
type Protocol uint8

const (
	Protocol6C Protocol = 1 << 1 // ISO18000-6C / EPC C1G2
	Protocol6B Protocol = 1 << 0 // ISO18000-6B
)

func (p Protocol) String() string {
	var s string
	if p&Protocol6C != 0 {
		s += "6C "
	}
	if p&Protocol6B != 0 {
		s += "6B "
	}
	if s == "" {
		return fmt.Sprintf("unknown(0x%02X)", byte(p))
	}
	return s[:len(s)-1] // trim trailing space
}

// FrequencyBand identifies the regional frequency band in use.
// Encoded in bits 7-6 of DMaxFre and DMinFre bytes.
type FrequencyBand uint8

const (
	FrequencyBandUser    FrequencyBand = 0b00 // user-defined band
	FrequencyBandChinese FrequencyBand = 0b01 // Chinese band 2 (920.125–925 MHz)
	FrequencyBandUS      FrequencyBand = 0b10 // US band (902.75–927.25 MHz)
	FrequencyBandKorean  FrequencyBand = 0b11 // Korean band (917.1–923.5 MHz)
)

func (b FrequencyBand) String() string {
	switch b {
	case FrequencyBandUser:
		return "User"
	case FrequencyBandChinese:
		return "Chinese-2"
	case FrequencyBandUS:
		return "US"
	case FrequencyBandKorean:
		return "Korean"
	default:
		return fmt.Sprintf("RFU(0x%02X)", byte(b))
	}
}

// FrequencyEncoding holds a decoded frequency byte (DMaxFre or DMinFre).
// Bits 7-6 encode the band; bits 5-0 encode the channel index N.
// Actual frequency: see FrequencyBand-specific formula in the datasheet (§8.4.2).
type FrequencyEncoding struct {
	Band    FrequencyBand
	Channel uint8 // bits 5-0, the N value in the frequency formula
}

// MHz returns the channel frequency in MHz, computed from the band formula.
// Returns 0 if the band is user-defined (no formula applies).
func (f FrequencyEncoding) MHz() float64 {
	switch f.Band {
	case FrequencyBandUser:
		return 902.6 + float64(f.Channel)*0.4
	case FrequencyBandChinese:
		return 920.125 + float64(f.Channel)*0.25
	case FrequencyBandUS:
		return 902.75 + float64(f.Channel)*0.5
	case FrequencyBandKorean:
		return 917.1 + float64(f.Channel)*0.2
	default:
		return 0
	}
}

func decodeFrequency(b byte) FrequencyEncoding {
	return FrequencyEncoding{
		Band:    FrequencyBand(b >> 6),
		Channel: b & 0x3F,
	}
}

// GetReaderInformationParams holds the parameters for the GetReaderInformation command.
// This command takes no parameters beyond the reader address already set on the Reader.
type GetReaderInformationParams struct{}

// GetReaderInformationResult holds the response data from the GetReaderInformation command.
// See datasheet §8.4.1 for field definitions.
type GetReaderInformationResult struct {
	// VersionMajor is the firmware major version number.
	VersionMajor uint8
	// VersionMinor is the firmware sub-version number.
	VersionMinor uint8
	// Type is the reader type byte (0x03 = RRU9803M).
	Type uint8
	// SupportedProtocols is a bitmask of tag protocols the reader supports.
	SupportedProtocols Protocol
	// MaxFreq is the reader's current maximum operating frequency.
	MaxFreq FrequencyEncoding
	// MinFreq is the reader's current minimum operating frequency.
	MinFreq FrequencyEncoding
	// Power is the TX output power in dBm (range 20–30; 0 = unknown).
	Power uint8
	// ScanTime is the inventory scan time multiplier; actual time = ScanTime * 100 ms.
	ScanTime uint8
}

// GetReaderInformation queries the reader for its configuration and firmware info.
//
// TX frame (§8.4.1):
//
//	[Len=0x04][Adr][Cmd=0x21][CRC_LSB][CRC_MSB]
//
// RX frame:
//
//	[Len=0x0D][Adr][0x21][Status=0x00][VerMaj][VerMin][Type][Tr_Type][DMaxFre][DMinFre][Power][Scntm][CRC_LSB][CRC_MSB]
func (r *Reader) GetReaderInformation(_ GetReaderInformationParams) (GetReaderInformationResult, error) {
	frame := buildFrame(r.addr, cmdGetReaderInformation, nil)

	resp, err := r.exchange(frame, txFieldsGetReaderInfo(r.addr, frame), cmdGetReaderInformation,
		func(raw []byte) []debugField { return rxFieldsGetReaderInfo(raw) })
	if err != nil {
		return GetReaderInformationResult{}, err
	}
	if resp.status != StatusSuccess {
		return GetReaderInformationResult{}, resp.status
	}

	// Response data: Version(2) + Type(1) + Tr_Type(1) + DMaxFre(1) + DMinFre(1) + Power(1) + Scntm(1) = 8 bytes
	if len(resp.data) < 8 {
		return GetReaderInformationResult{}, fmt.Errorf("response data too short: got %d bytes, want 8", len(resp.data))
	}

	d := resp.data
	return GetReaderInformationResult{
		VersionMajor:       d[0],
		VersionMinor:       d[1],
		Type:               d[2],
		SupportedProtocols: Protocol(d[3]),
		MaxFreq:            decodeFrequency(d[4]),
		MinFreq:            decodeFrequency(d[5]),
		Power:              d[6],
		ScanTime:           d[7],
	}, nil
}

// txFieldsGetReaderInfo returns the debug field annotations for the TX frame.
func txFieldsGetReaderInfo(addr byte, frame []byte) []debugField {
	crc := crc16(frame[:len(frame)-2])
	return []debugField{
		{0, 1, "Len", fmt.Sprintf("frame length (excl. self) = %d", frame[0])},
		{1, 1, "Adr", fmt.Sprintf("reader address = 0x%02X", addr)},
		{2, 1, "Cmd", fmt.Sprintf("GetReaderInformation (0x%02X)", cmdGetReaderInformation)},
		{3, 2, "CRC-16", fmt.Sprintf("0x%04X (LSB first)", crc)},
	}
}

// rxFieldsGetReaderInfo returns the debug field annotations for the RX frame.
// raw may be partially populated; bounds checks are handled by the hex formatter in debugFrame.
func rxFieldsGetReaderInfo(raw []byte) []debugField {
	fields := []debugField{
		{0, 1, "Len", "frame length (excl. self)"},
		{1, 1, "Adr", "reader address (echo)"},
		{2, 1, "reCmd", fmt.Sprintf("echoed command = GetReaderInformation (0x%02X)", cmdGetReaderInformation)},
		{3, 1, "Status", statusDetail(raw, 3)},
	}
	if len(raw) >= 14 {
		d := raw[4:]
		maxFreq := decodeFrequency(d[4])
		minFreq := decodeFrequency(d[5])
		fields = append(fields,
			debugField{4, 1, "Version.Major", fmt.Sprintf("%d", d[0])},
			debugField{5, 1, "Version.Minor", fmt.Sprintf("%d", d[1])},
			debugField{6, 1, "Type", fmt.Sprintf("reader type = 0x%02X", d[2])},
			debugField{7, 1, "Tr_Type", fmt.Sprintf("protocols: %s (raw 0x%02X)", Protocol(d[3]), d[3])},
			debugField{8, 1, "DMaxFre", fmt.Sprintf("band=%s channel=%d (%.3f MHz)", maxFreq.Band, maxFreq.Channel, maxFreq.MHz())},
			debugField{9, 1, "DMinFre", fmt.Sprintf("band=%s channel=%d (%.3f MHz)", minFreq.Band, minFreq.Channel, minFreq.MHz())},
			debugField{10, 1, "Power", powerDetail(d[6])},
			debugField{11, 1, "Scntm", fmt.Sprintf("scan time = %d * 100ms = %dms", d[7], int(d[7])*100)},
			debugField{12, 2, "CRC-16", "checksum (LSB first)"},
		)
	}
	return fields
}

// statusDetail returns a human-readable description of the Status byte at offset i in raw.
func statusDetail(raw []byte, i int) string {
	if i >= len(raw) {
		return "?"
	}
	s := Status(raw[i])
	return fmt.Sprintf("%s (0x%02X)", s, byte(s))
}

func powerDetail(p uint8) string {
	if p == 0 {
		return "output power unknown"
	}
	return fmt.Sprintf("%d dBm", p)
}
