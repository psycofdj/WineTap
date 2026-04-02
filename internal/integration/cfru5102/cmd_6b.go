package cfru5102

import "fmt"

const (
	cmdInventorySignal6B   byte = 0x50
	cmdInventoryMultiple6B byte = 0x51
	cmdReadData6B          byte = 0x52
	cmdWriteData6B         byte = 0x53
	cmdCheckLock6B         byte = 0x54
	cmdLock6B              byte = 0x55
)

// Condition6B specifies the comparison condition used in InventoryMultiple6B.
type Condition6B uint8

const (
	Condition6BEqual   Condition6B = 0x00
	Condition6BUnequal Condition6B = 0x01
	Condition6BGreater Condition6B = 0x02
	Condition6BLower   Condition6B = 0x03
)

func (c Condition6B) String() string {
	switch c {
	case Condition6BEqual:
		return "Equal"
	case Condition6BUnequal:
		return "Unequal"
	case Condition6BGreater:
		return "Greater"
	case Condition6BLower:
		return "Lower"
	default:
		return fmt.Sprintf("Condition6B(0x%02X)", uint8(c))
	}
}

// InventorySignal6BParams holds the parameters for the InventorySignal6B command.
type InventorySignal6BParams struct{}

// InventorySignal6BResult holds the response data from the InventorySignal6B command.
type InventorySignal6BResult struct {
	UID [8]byte // raw UID as received (low byte first)
}

// InventorySignal6B reads a single ISO18000-6B tag UID (§8.3.1).
//
// TX frame: [0x04][Adr][0x50][CRC_LSB][CRC_MSB]
//
// RX data: ID(8 bytes) — tag UID, low byte first.
func (r *Reader) InventorySignal6B(_ InventorySignal6BParams) (InventorySignal6BResult, error) {
	frame := buildFrame(r.addr, cmdInventorySignal6B, nil)

	resp, err := r.exchange(frame,
		txHeaderFields(frame, "InventorySignal6B", cmdInventorySignal6B),
		cmdInventorySignal6B,
		func(raw []byte) []debugField { return rxFieldsInventorySignal6B(raw) },
	)
	if err != nil {
		return InventorySignal6BResult{}, err
	}
	if resp.status != StatusSuccess {
		return InventorySignal6BResult{}, resp.status
	}
	if len(resp.data) < 8 {
		return InventorySignal6BResult{}, fmt.Errorf("InventorySignal6B: response data too short: %d bytes", len(resp.data))
	}

	var uid [8]byte
	copy(uid[:], resp.data[:8])
	return InventorySignal6BResult{UID: uid}, nil
}

func rxFieldsInventorySignal6B(raw []byte) []debugField {
	fields := rxHeaderFields(raw, "InventorySignal6B", cmdInventorySignal6B)
	if len(raw) >= 14 {
		fields = append(fields,
			debugField{4, 8, "ID", fmt.Sprintf("UID (low byte first): %s", hexDump(raw, 4, 8))},
			debugField{12, 2, "CRC-16", "checksum (LSB first)"},
		)
	}
	return fields
}

// InventoryMultiple6BParams holds the parameters for the InventoryMultiple6B command.
type InventoryMultiple6BParams struct {
	Condition Condition6B
	Address   uint8
	Mask      uint8
	WordData  [8]byte
}

// InventoryMultiple6BResult holds the response data from the InventoryMultiple6B command.
type InventoryMultiple6BResult struct {
	UIDs   [][8]byte
	Status Status
}

// InventoryMultiple6B scans for multiple ISO18000-6B tags matching a condition (§8.3.2).
//
// TX frame: [0x0F][Adr][0x51][Condition][Address][Mask][Word_data(8 bytes)][CRC_LSB][CRC_MSB]
//
// RX: [Len][Adr][0x51][Status][Num][UID1(8)][UID2(8)...][CRC_LSB][CRC_MSB]
//
// Status 0x15–0x18 are inventory success codes.
func (r *Reader) InventoryMultiple6B(p InventoryMultiple6BParams) (InventoryMultiple6BResult, error) {
	data := []byte{byte(p.Condition), p.Address, p.Mask}
	data = append(data, p.WordData[:]...)

	frame := buildFrame(r.addr, cmdInventoryMultiple6B, data)

	resp, err := r.exchange(frame,
		txFieldsInventoryMultiple6B(frame, p),
		cmdInventoryMultiple6B,
		func(raw []byte) []debugField { return rxFieldsInventoryMultiple6B(raw) },
	)
	if err != nil {
		return InventoryMultiple6BResult{}, err
	}

	// Status 0x15–0x18 are 6B inventory success codes.
	if resp.status < Status6BInventoryFinished || resp.status > Status6BInventoryFlashFull {
		return InventoryMultiple6BResult{}, resp.status
	}

	if len(resp.data) < 1 {
		return InventoryMultiple6BResult{}, fmt.Errorf("InventoryMultiple6B: response data too short")
	}
	num := int(resp.data[0])
	if len(resp.data) < 1+num*8 {
		return InventoryMultiple6BResult{}, fmt.Errorf("InventoryMultiple6B: data truncated: need %d bytes for %d UIDs, have %d", num*8, num, len(resp.data)-1)
	}

	uids := make([][8]byte, num)
	for i := range num {
		copy(uids[i][:], resp.data[1+i*8:1+i*8+8])
	}

	return InventoryMultiple6BResult{UIDs: uids, Status: resp.status}, nil
}

func txFieldsInventoryMultiple6B(frame []byte, p InventoryMultiple6BParams) []debugField {
	fields := txHeaderFields(frame, "InventoryMultiple6B", cmdInventoryMultiple6B)
	fb := newFB(frame, 3)
	fb.add(1, "Condition", fmt.Sprintf("%s (0x%02X)", p.Condition, uint8(p.Condition)))
	fb.add(1, "Address", fmt.Sprintf("byte address = 0x%02X", p.Address))
	fb.add(1, "Mask", fmt.Sprintf("bit mask = 0x%02X", p.Mask))
	fb.add(8, "Word_data", fmt.Sprintf("compare value: %s", hexDump(frame, 9, 8)))
	return append(fields, fb.build()...)
}

func rxFieldsInventoryMultiple6B(raw []byte) []debugField {
	fields := rxHeaderFields(raw, "InventoryMultiple6B", cmdInventoryMultiple6B)
	if len(raw) < 7 {
		return fields
	}
	fb := newFB(raw, 4)
	num := 0
	if len(raw) > 4 {
		num = int(raw[4])
		fb.add(1, "Num", fmt.Sprintf("tag count = %d", num))
	}
	for i := range num {
		start := 5 + i*8
		if start+8 > len(raw)-2 {
			break
		}
		fb.add(8, fmt.Sprintf("UID%d", i+1), fmt.Sprintf("(low byte first): %s", hexDump(raw, start, 8)))
	}
	fb.add(2, "CRC-16", "checksum (LSB first)")
	return append(fields, fb.build()...)
}

// ReadData6BParams holds the parameters for the ReadData6B command.
type ReadData6BParams struct {
	Address uint8
	UID     [8]byte
	Num     uint8 // 1–32 bytes to read
}

// ReadData6BResult holds the response data from the ReadData6B command.
type ReadData6BResult struct {
	Data []byte
}

// ReadData6B reads bytes from an ISO18000-6B tag's memory (§8.3.3).
//
// TX frame: [0x0E][Adr][0x52][Address][ID(8 bytes)][Num][CRC_LSB][CRC_MSB]
//
// RX data: read bytes (low byte first).
func (r *Reader) ReadData6B(p ReadData6BParams) (ReadData6BResult, error) {
	data := []byte{p.Address}
	data = append(data, p.UID[:]...)
	data = append(data, p.Num)

	frame := buildFrame(r.addr, cmdReadData6B, data)

	resp, err := r.exchange(frame,
		txFieldsReadData6B(frame, p),
		cmdReadData6B,
		func(raw []byte) []debugField { return rxFieldsReadData6B(raw) },
	)
	if err != nil {
		return ReadData6BResult{}, err
	}
	if resp.status != StatusSuccess {
		return ReadData6BResult{}, resp.status
	}

	out := make([]byte, len(resp.data))
	copy(out, resp.data)
	return ReadData6BResult{Data: out}, nil
}

func txFieldsReadData6B(frame []byte, p ReadData6BParams) []debugField {
	fields := txHeaderFields(frame, "ReadData6B", cmdReadData6B)
	fb := newFB(frame, 3)
	fb.add(1, "Address", fmt.Sprintf("byte address = 0x%02X", p.Address))
	fb.add(8, "ID", fmt.Sprintf("UID (low byte first): %s", hexDump(frame, 4, 8)))
	fb.add(1, "Num", fmt.Sprintf("byte count = %d", p.Num))
	return append(fields, fb.build()...)
}

func rxFieldsReadData6B(raw []byte) []debugField {
	fields := rxHeaderFields(raw, "ReadData6B", cmdReadData6B)
	if len(raw) >= 7 {
		dataLen := len(raw) - 6
		if dataLen > 0 {
			fb := newFB(raw, 4)
			fb.add(dataLen, "Data", fmt.Sprintf("%d bytes (low byte first)", dataLen))
			fb.add(2, "CRC-16", "checksum (LSB first)")
			fields = append(fields, fb.build()...)
		}
	}
	return fields
}

// WriteData6BParams holds the parameters for the WriteData6B command.
type WriteData6BParams struct {
	Address uint8
	UID     [8]byte
	Data    []byte // 1–32 bytes
}

// WriteData6BResult holds the response data from the WriteData6B command.
type WriteData6BResult struct{}

// WriteData6B writes bytes to an ISO18000-6B tag's memory (§8.3.4).
//
// TX data: [Address][ID(8 bytes)][Wdata(variable)]
func (r *Reader) WriteData6B(p WriteData6BParams) (WriteData6BResult, error) {
	if len(p.Data) == 0 || len(p.Data) > 32 {
		return WriteData6BResult{}, fmt.Errorf("WriteData6B: data length %d out of range 1–32", len(p.Data))
	}

	data := []byte{p.Address}
	data = append(data, p.UID[:]...)
	data = append(data, p.Data...)

	frame := buildFrame(r.addr, cmdWriteData6B, data)

	resp, err := r.exchange(frame,
		txFieldsWriteData6B(frame, p),
		cmdWriteData6B,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "WriteData6B", cmdWriteData6B) },
	)
	if err != nil {
		return WriteData6BResult{}, err
	}
	if resp.status != StatusSuccess {
		return WriteData6BResult{}, resp.status
	}
	return WriteData6BResult{}, nil
}

func txFieldsWriteData6B(frame []byte, p WriteData6BParams) []debugField {
	fields := txHeaderFields(frame, "WriteData6B", cmdWriteData6B)
	fb := newFB(frame, 3)
	fb.add(1, "Address", fmt.Sprintf("byte address = 0x%02X", p.Address))
	fb.add(8, "ID", fmt.Sprintf("UID (low byte first): %s", hexDump(frame, 4, 8)))
	if len(p.Data) > 0 {
		fb.add(len(p.Data), "Wdata", fmt.Sprintf("%d bytes to write", len(p.Data)))
	}
	return append(fields, fb.build()...)
}

// CheckLock6BParams holds the parameters for the CheckLock6B command.
type CheckLock6BParams struct {
	Address uint8
	UID     [8]byte
}

// CheckLock6BResult holds the response data from the CheckLock6B command.
type CheckLock6BResult struct {
	Locked bool // true if the byte is locked
}

// CheckLock6B checks whether a specific byte of an ISO18000-6B tag is locked (§8.3.5).
//
// TX frame: [0x0D][Adr][0x54][Address][ID(8 bytes)][CRC_LSB][CRC_MSB]
//
// RX data: [LockState] — 0x00 = unlocked, 0x01 = locked.
func (r *Reader) CheckLock6B(p CheckLock6BParams) (CheckLock6BResult, error) {
	data := []byte{p.Address}
	data = append(data, p.UID[:]...)

	frame := buildFrame(r.addr, cmdCheckLock6B, data)

	resp, err := r.exchange(frame,
		txFieldsCheckLock6B(frame, p),
		cmdCheckLock6B,
		func(raw []byte) []debugField { return rxFieldsCheckLock6B(raw) },
	)
	if err != nil {
		return CheckLock6BResult{}, err
	}
	if resp.status != StatusSuccess {
		return CheckLock6BResult{}, resp.status
	}
	if len(resp.data) < 1 {
		return CheckLock6BResult{}, fmt.Errorf("CheckLock6B: response data too short")
	}
	return CheckLock6BResult{Locked: resp.data[0] == 0x01}, nil
}

func txFieldsCheckLock6B(frame []byte, p CheckLock6BParams) []debugField {
	fields := txHeaderFields(frame, "CheckLock6B", cmdCheckLock6B)
	fb := newFB(frame, 3)
	fb.add(1, "Address", fmt.Sprintf("byte address = 0x%02X", p.Address))
	fb.add(8, "ID", fmt.Sprintf("UID (low byte first): %s", hexDump(frame, 4, 8)))
	return append(fields, fb.build()...)
}

func rxFieldsCheckLock6B(raw []byte) []debugField {
	fields := rxHeaderFields(raw, "CheckLock6B", cmdCheckLock6B)
	if len(raw) >= 7 {
		lockState := "unknown"
		if len(raw) > 4 {
			switch raw[4] {
			case 0x00:
				lockState = "unlocked (0x00)"
			case 0x01:
				lockState = "locked (0x01)"
			}
		}
		fields = append(fields,
			debugField{4, 1, "LockState", lockState},
			debugField{5, 2, "CRC-16", "checksum (LSB first)"},
		)
	}
	return fields
}

// Lock6BParams holds the parameters for the Lock6B command.
type Lock6BParams struct {
	Address uint8
	UID     [8]byte
}

// Lock6BResult holds the response data from the Lock6B command.
type Lock6BResult struct{}

// Lock6B permanently locks a specific byte of an ISO18000-6B tag (§8.3.6).
//
// TX frame: [0x0D][Adr][0x55][Address][ID(8 bytes)][CRC_LSB][CRC_MSB]
func (r *Reader) Lock6B(p Lock6BParams) (Lock6BResult, error) {
	data := []byte{p.Address}
	data = append(data, p.UID[:]...)

	frame := buildFrame(r.addr, cmdLock6B, data)

	resp, err := r.exchange(frame,
		txFieldsLock6B(frame, p),
		cmdLock6B,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "Lock6B", cmdLock6B) },
	)
	if err != nil {
		return Lock6BResult{}, err
	}
	if resp.status != StatusSuccess {
		return Lock6BResult{}, resp.status
	}
	return Lock6BResult{}, nil
}

func txFieldsLock6B(frame []byte, p Lock6BParams) []debugField {
	fields := txHeaderFields(frame, "Lock6B", cmdLock6B)
	fb := newFB(frame, 3)
	fb.add(1, "Address", fmt.Sprintf("byte address = 0x%02X", p.Address))
	fb.add(8, "ID", fmt.Sprintf("UID (low byte first): %s", hexDump(frame, 4, 8)))
	return append(fields, fb.build()...)
}
