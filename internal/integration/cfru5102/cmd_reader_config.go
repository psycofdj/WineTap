package cfru5102

import "fmt"

const (
	cmdSetRegion            byte = 0x22
	cmdSetAddress           byte = 0x24
	cmdSetScanTime          byte = 0x25
	cmdSetBaudRate          byte = 0x28
	cmdSetPower             byte = 0x2F
	cmdAcoustoOpticControl  byte = 0x33
)

// SetRegionParams holds the parameters for the SetRegion command.
type SetRegionParams struct {
	MaxFreq FrequencyEncoding
	MinFreq FrequencyEncoding
}

// SetRegionResult holds the response data from the SetRegion command.
type SetRegionResult struct{}

// encodeFrequency encodes a FrequencyEncoding back to its wire byte representation.
func encodeFrequency(f FrequencyEncoding) byte {
	return (byte(f.Band) << 6) | (f.Channel & 0x3F)
}

// SetRegion sets the operating frequency range of the reader (§8.4.2).
//
// TX frame: [0x06][Adr][0x22][MaxFre][MinFre][CRC_LSB][CRC_MSB]
func (r *Reader) SetRegion(p SetRegionParams) (SetRegionResult, error) {
	maxByte := encodeFrequency(p.MaxFreq)
	minByte := encodeFrequency(p.MinFreq)

	frame := buildFrame(r.addr, cmdSetRegion, []byte{maxByte, minByte})

	resp, err := r.exchange(frame,
		txFieldsSetRegion(frame, p),
		cmdSetRegion,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "SetRegion", cmdSetRegion) },
	)
	if err != nil {
		return SetRegionResult{}, err
	}
	if resp.status != StatusSuccess {
		return SetRegionResult{}, resp.status
	}
	return SetRegionResult{}, nil
}

func txFieldsSetRegion(frame []byte, p SetRegionParams) []debugField {
	fields := txHeaderFields(frame, "SetRegion", cmdSetRegion)
	fb := newFB(frame, 3)
	fb.add(1, "MaxFre", fmt.Sprintf("band=%s channel=%d (%.3f MHz)", p.MaxFreq.Band, p.MaxFreq.Channel, p.MaxFreq.MHz()))
	fb.add(1, "MinFre", fmt.Sprintf("band=%s channel=%d (%.3f MHz)", p.MinFreq.Band, p.MinFreq.Channel, p.MinFreq.MHz()))
	return append(fields, fb.build()...)
}

// SetAddressParams holds the parameters for the SetAddress command.
type SetAddressParams struct {
	NewAddress byte
}

// SetAddressResult holds the response data from the SetAddress command.
type SetAddressResult struct{}

// SetAddress sets a new address on the reader (§8.4.3).
//
// TX frame: [0x05][Adr][0x24][NewAddress][CRC_LSB][CRC_MSB]
//
// Note: Adr in the frame is the OLD address. Writing 0xFF causes the reader
// to set its address to 0x00.
func (r *Reader) SetAddress(p SetAddressParams) (SetAddressResult, error) {
	frame := buildFrame(r.addr, cmdSetAddress, []byte{p.NewAddress})

	resp, err := r.exchange(frame,
		txFieldsSetAddress(frame, p),
		cmdSetAddress,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "SetAddress", cmdSetAddress) },
	)
	if err != nil {
		return SetAddressResult{}, err
	}
	if resp.status != StatusSuccess {
		return SetAddressResult{}, resp.status
	}
	return SetAddressResult{}, nil
}

func txFieldsSetAddress(frame []byte, p SetAddressParams) []debugField {
	fields := txHeaderFields(frame, "SetAddress", cmdSetAddress)
	fb := newFB(frame, 3)
	newAddrDesc := fmt.Sprintf("new address = 0x%02X", p.NewAddress)
	if p.NewAddress == 0xFF {
		newAddrDesc += " (will be reset to 0x00)"
	}
	fb.add(1, "NewAddress", newAddrDesc)
	return append(fields, fb.build()...)
}

// SetScanTimeParams holds the parameters for the SetScanTime command.
type SetScanTimeParams struct {
	ScanTime byte // multiplier; actual = ScanTime * 100ms; range 3–255; values 0–2 auto-corrected to 10
}

// SetScanTimeResult holds the response data from the SetScanTime command.
type SetScanTimeResult struct{}

// SetScanTime sets the inventory scan time multiplier (§8.4.4).
//
// TX frame: [0x05][Adr][0x25][Scantime][CRC_LSB][CRC_MSB]
//
// Range 0x03–0xFF; values 0x00–0x02 are auto-corrected to 0x0A by the reader.
func (r *Reader) SetScanTime(p SetScanTimeParams) (SetScanTimeResult, error) {
	frame := buildFrame(r.addr, cmdSetScanTime, []byte{p.ScanTime})

	resp, err := r.exchange(frame,
		txFieldsSetScanTime(frame, p),
		cmdSetScanTime,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "SetScanTime", cmdSetScanTime) },
	)
	if err != nil {
		return SetScanTimeResult{}, err
	}
	if resp.status != StatusSuccess {
		return SetScanTimeResult{}, resp.status
	}
	return SetScanTimeResult{}, nil
}

func txFieldsSetScanTime(frame []byte, p SetScanTimeParams) []debugField {
	fields := txHeaderFields(frame, "SetScanTime", cmdSetScanTime)
	fb := newFB(frame, 3)
	actual := p.ScanTime
	note := ""
	if actual < 3 {
		note = " (will be auto-corrected to 10 by reader)"
		actual = 10
	}
	fb.add(1, "Scantime", fmt.Sprintf("%d * 100ms = %dms%s", p.ScanTime, int(actual)*100, note))
	return append(fields, fb.build()...)
}

// SetBaudRateParams holds the parameters for the SetBaudRate command.
type SetBaudRateParams struct {
	BaudRate BaudRate
}

// SetBaudRateResult holds the response data from the SetBaudRate command.
type SetBaudRateResult struct{}

// SetBaudRate configures the reader's serial baud rate (§8.4.5).
//
// TX frame: [0x05][Adr][0x28][BaudRate][CRC_LSB][CRC_MSB]
func (r *Reader) SetBaudRate(p SetBaudRateParams) (SetBaudRateResult, error) {
	frame := buildFrame(r.addr, cmdSetBaudRate, []byte{byte(p.BaudRate)})

	resp, err := r.exchange(frame,
		txFieldsSetBaudRate(frame, p),
		cmdSetBaudRate,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "SetBaudRate", cmdSetBaudRate) },
	)
	if err != nil {
		return SetBaudRateResult{}, err
	}
	if resp.status != StatusSuccess {
		return SetBaudRateResult{}, resp.status
	}
	return SetBaudRateResult{}, nil
}

func txFieldsSetBaudRate(frame []byte, p SetBaudRateParams) []debugField {
	fields := txHeaderFields(frame, "SetBaudRate", cmdSetBaudRate)
	fb := newFB(frame, 3)
	fb.add(1, "BaudRate", fmt.Sprintf("%s baud (0x%02X)", p.BaudRate, uint8(p.BaudRate)))
	return append(fields, fb.build()...)
}

// SetPowerParams holds the parameters for the SetPower command.
type SetPowerParams struct {
	Power uint8 // TX output power in dBm, range 20–30
}

// SetPowerResult holds the response data from the SetPower command.
type SetPowerResult struct{}

// SetPower sets the reader's RF output power (§8.4.6).
//
// TX frame: [0x05][Adr][0x2F][Pwr][CRC_LSB][CRC_MSB]
//
// Range: 20–30 dBm.
func (r *Reader) SetPower(p SetPowerParams) (SetPowerResult, error) {
	frame := buildFrame(r.addr, cmdSetPower, []byte{p.Power})

	resp, err := r.exchange(frame,
		txFieldsSetPower(frame, p),
		cmdSetPower,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "SetPower", cmdSetPower) },
	)
	if err != nil {
		return SetPowerResult{}, err
	}
	if resp.status != StatusSuccess {
		return SetPowerResult{}, resp.status
	}
	return SetPowerResult{}, nil
}

func txFieldsSetPower(frame []byte, p SetPowerParams) []debugField {
	fields := txHeaderFields(frame, "SetPower", cmdSetPower)
	fb := newFB(frame, 3)
	fb.add(1, "Pwr", fmt.Sprintf("%d dBm", p.Power))
	return append(fields, fb.build()...)
}

// AcoustoOpticControlParams holds the parameters for the AcoustoOpticControl command.
type AcoustoOpticControlParams struct {
	ActiveT uint8 // active time in units of 50ms
	SilentT uint8 // silent time in units of 50ms
	Times   uint8 // number of repetitions
}

// AcoustoOpticControlResult holds the response data from the AcoustoOpticControl command.
type AcoustoOpticControlResult struct{}

// AcoustoOpticControl triggers the reader's buzzer/LED (§8.4.7).
//
// TX frame: [0x07][Adr][0x33][ActiveT][SilentT][Times][CRC_LSB][CRC_MSB]
func (r *Reader) AcoustoOpticControl(p AcoustoOpticControlParams) (AcoustoOpticControlResult, error) {
	frame := buildFrame(r.addr, cmdAcoustoOpticControl, []byte{p.ActiveT, p.SilentT, p.Times})

	resp, err := r.exchange(frame,
		txFieldsAcoustoOpticControl(frame, p),
		cmdAcoustoOpticControl,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "AcoustoOpticControl", cmdAcoustoOpticControl) },
	)
	if err != nil {
		return AcoustoOpticControlResult{}, err
	}
	if resp.status != StatusSuccess {
		return AcoustoOpticControlResult{}, resp.status
	}
	return AcoustoOpticControlResult{}, nil
}

func txFieldsAcoustoOpticControl(frame []byte, p AcoustoOpticControlParams) []debugField {
	fields := txHeaderFields(frame, "AcoustoOpticControl", cmdAcoustoOpticControl)
	fb := newFB(frame, 3)
	fb.add(1, "ActiveT", fmt.Sprintf("%d * 50ms = %dms active", p.ActiveT, int(p.ActiveT)*50))
	fb.add(1, "SilentT", fmt.Sprintf("%d * 50ms = %dms silent", p.SilentT, int(p.SilentT)*50))
	fb.add(1, "Times", fmt.Sprintf("%d repetitions", p.Times))
	return append(fields, fb.build()...)
}
