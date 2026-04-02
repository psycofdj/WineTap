package cfru5102

import (
	"encoding/binary"
	"fmt"
)

const (
	cmdReadData    byte = 0x02
	cmdWriteData   byte = 0x03
	cmdWriteEPC    byte = 0x04
	cmdBlockErase  byte = 0x07
	cmdBlockWrite  byte = 0x10
)

// ReadDataParams holds the parameters for the ReadData command.
type ReadDataParams struct {
	EPC     []byte     // tag EPC for selection (nil/empty = match any)
	Mem     MemoryBank
	WordPtr uint8  // starting word address
	Num     uint8  // number of 16-bit words to read (1–119)
	Pwd     [4]byte // access password (zeros = no password)
	MaskAdr uint8
	MaskLen uint8
}

// ReadDataResult holds the response data from the ReadData command.
type ReadDataResult struct {
	Words []uint16 // words read, big-endian within each word
}

// ReadData reads words from a tag's memory bank (§8.2.2).
//
// TX data: [ENum][EPC(ENum*2 bytes)][Mem][WordPtr][Num][Pwd(4 bytes)][MaskAdr][MaskLen]
func (r *Reader) ReadData(p ReadDataParams) (ReadDataResult, error) {
	enum, epcData, err := encodeEPC(p.EPC)
	if err != nil {
		return ReadDataResult{}, fmt.Errorf("ReadData: %w", err)
	}

	data := []byte{enum}
	data = append(data, epcData...)
	data = append(data, byte(p.Mem), p.WordPtr, p.Num)
	data = appendPassword(data, p.Pwd)
	data = appendMask(data, p.MaskAdr, p.MaskLen)

	frame := buildFrame(r.addr, cmdReadData, data)

	resp, err := r.exchange(frame,
		txFieldsReadData(frame, p),
		cmdReadData,
		func(raw []byte) []debugField { return rxFieldsReadData(raw, p) },
	)
	if err != nil {
		return ReadDataResult{}, err
	}
	if resp.status != StatusSuccess {
		return ReadDataResult{}, resp.status
	}

	if len(resp.data)%2 != 0 {
		return ReadDataResult{}, fmt.Errorf("ReadData: response data length %d is not even", len(resp.data))
	}
	words := make([]uint16, len(resp.data)/2)
	for i := range words {
		words[i] = binary.BigEndian.Uint16(resp.data[i*2 : i*2+2])
	}
	return ReadDataResult{Words: words}, nil
}

func txFieldsReadData(frame []byte, p ReadDataParams) []debugField {
	fields := txHeaderFields(frame, "ReadData", cmdReadData)
	epcLen := len(p.EPC)
	fb := newFB(frame, 3)
	fb.add(1, "ENum", fmt.Sprintf("%d words = %d bytes", epcLen/2, epcLen))
	if epcLen > 0 {
		fb.add(epcLen, "EPC", epcDetail(p.EPC))
	}
	fb.add(1, "Mem", fmt.Sprintf("%s (0x%02X)", p.Mem, uint8(p.Mem)))
	fb.add(1, "WordPtr", fmt.Sprintf("word address = %d", p.WordPtr))
	fb.add(1, "Num", fmt.Sprintf("word count = %d", p.Num))
	fb.add(4, "Pwd", pwdDetail("access password (0x00000000 = no auth)", p.Pwd))
	fb.add(1, "MaskAdr", fmt.Sprintf("0x%02X", p.MaskAdr))
	fb.add(1, "MaskLen", fmt.Sprintf("%d", p.MaskLen))
	return append(fields, fb.build()...)
}

func rxFieldsReadData(raw []byte, p ReadDataParams) []debugField {
	fields := rxHeaderFields(raw, "ReadData", cmdReadData)
	if len(raw) < 7 {
		return fields
	}
	dataLen := len(raw) - 6 // excl Len, Adr, reCmd, Status, CRC(2)
	if dataLen > 0 {
		fb := newFB(raw, 4)
		fb.add(dataLen, "Words", fmt.Sprintf("%d 16-bit words", dataLen/2))
		fb.add(2, "CRC-16", "checksum (LSB first)")
		fields = append(fields, fb.build()...)
	}
	_ = p
	return fields
}

// WriteDataParams holds the parameters for the WriteData command.
type WriteDataParams struct {
	EPC     []byte     // tag EPC for selection (nil/empty = match any)
	Mem     MemoryBank
	WordPtr uint8
	Words   []uint16 // data to write; WNum = len(Words)
	Pwd     [4]byte
	MaskAdr uint8
	MaskLen uint8
}

// WriteDataResult holds the response data from the WriteData command.
type WriteDataResult struct{}

// WriteData writes words to a tag's memory bank (§8.2.3).
//
// TX data: [WNum][ENum][EPC(ENum*2)][Mem][WordPtr][Wdt(WNum*2 bytes)][Pwd(4)][MaskAdr][MaskLen]
func (r *Reader) WriteData(p WriteDataParams) (WriteDataResult, error) {
	enum, epcData, err := encodeEPC(p.EPC)
	if err != nil {
		return WriteDataResult{}, fmt.Errorf("WriteData: %w", err)
	}

	wnum := byte(len(p.Words))
	data := []byte{wnum, enum}
	data = append(data, epcData...)
	data = append(data, byte(p.Mem), p.WordPtr)
	for _, w := range p.Words {
		data = append(data, byte(w>>8), byte(w))
	}
	data = appendPassword(data, p.Pwd)
	data = appendMask(data, p.MaskAdr, p.MaskLen)

	frame := buildFrame(r.addr, cmdWriteData, data)

	resp, err := r.exchange(frame,
		txFieldsWriteData(frame, p),
		cmdWriteData,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "WriteData", cmdWriteData) },
	)
	if err != nil {
		return WriteDataResult{}, err
	}
	if resp.status != StatusSuccess {
		return WriteDataResult{}, resp.status
	}
	return WriteDataResult{}, nil
}

func txFieldsWriteData(frame []byte, p WriteDataParams) []debugField {
	fields := txHeaderFields(frame, "WriteData", cmdWriteData)
	epcLen := len(p.EPC)
	fb := newFB(frame, 3)
	fb.add(1, "WNum", fmt.Sprintf("word count = %d (%d bytes)", len(p.Words), len(p.Words)*2))
	fb.add(1, "ENum", fmt.Sprintf("%d words = %d bytes", epcLen/2, epcLen))
	if epcLen > 0 {
		fb.add(epcLen, "EPC", epcDetail(p.EPC))
	}
	fb.add(1, "Mem", fmt.Sprintf("%s (0x%02X)", p.Mem, uint8(p.Mem)))
	fb.add(1, "WordPtr", fmt.Sprintf("word address = %d", p.WordPtr))
	if len(p.Words) > 0 {
		fb.add(len(p.Words)*2, "Wdt", fmt.Sprintf("%d words to write", len(p.Words)))
	}
	fb.add(4, "Pwd", pwdDetail("access password (0x00000000 = no auth)", p.Pwd))
	fb.add(1, "MaskAdr", fmt.Sprintf("0x%02X", p.MaskAdr))
	fb.add(1, "MaskLen", fmt.Sprintf("%d", p.MaskLen))
	return append(fields, fb.build()...)
}

// WriteEPCParams holds the parameters for the WriteEPC command.
type WriteEPCParams struct {
	Pwd [4]byte
	EPC []byte // new EPC to write
}

// WriteEPCResult holds the response data from the WriteEPC command.
type WriteEPCResult struct{}

// WriteEPC writes a new EPC to a random tag in the RF field (§8.2.4).
//
// TX frame: [Len][Adr][0x04][ENum][Pwd(4)][WEPC(ENum*2 bytes)][CRC_LSB][CRC_MSB]
//
// Note: ENum encodes the length of the new EPC in words. There is no prior EPC
// selection — this writes to whichever tag is in the field.
func (r *Reader) WriteEPC(p WriteEPCParams) (WriteEPCResult, error) {
	enum, epcData, err := encodeEPC(p.EPC)
	if err != nil {
		return WriteEPCResult{}, fmt.Errorf("WriteEPC: %w", err)
	}
	if len(p.EPC) == 0 {
		return WriteEPCResult{}, fmt.Errorf("WriteEPC: EPC must not be empty")
	}

	data := []byte{enum}
	data = appendPassword(data, p.Pwd)
	data = append(data, epcData...)

	frame := buildFrame(r.addr, cmdWriteEPC, data)

	resp, err := r.exchange(frame,
		txFieldsWriteEPC(frame, p),
		cmdWriteEPC,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "WriteEPC", cmdWriteEPC) },
	)
	if err != nil {
		return WriteEPCResult{}, err
	}
	if resp.status != StatusSuccess {
		return WriteEPCResult{}, resp.status
	}
	return WriteEPCResult{}, nil
}

func txFieldsWriteEPC(frame []byte, p WriteEPCParams) []debugField {
	fields := txHeaderFields(frame, "WriteEPC", cmdWriteEPC)
	epcLen := len(p.EPC)
	fb := newFB(frame, 3)
	fb.add(1, "ENum", fmt.Sprintf("%d words = %d bytes (new EPC length)", epcLen/2, epcLen))
	fb.add(4, "Pwd", pwdDetail("access password (0x00000000 = no auth)", p.Pwd))
	if epcLen > 0 {
		fb.add(epcLen, "WEPC", epcDetail(p.EPC))
	}
	return append(fields, fb.build()...)
}

// BlockEraseParams holds the parameters for the BlockErase command.
type BlockEraseParams struct {
	EPC     []byte     // tag EPC for selection (nil/empty = match any)
	Mem     MemoryBank
	WordPtr uint8  // must be > 0 when erasing EPC memory
	Num     uint8  // number of words to erase
	Pwd     [4]byte
	MaskAdr uint8
	MaskLen uint8
}

// BlockEraseResult holds the response data from the BlockErase command.
type BlockEraseResult struct{}

// BlockErase erases words in a tag's memory bank (§8.2.7).
//
// TX data: [ENum][EPC(ENum*2)][Mem][WordPtr][Num][Pwd(4)][MaskAdr][MaskLen]
func (r *Reader) BlockErase(p BlockEraseParams) (BlockEraseResult, error) {
	enum, epcData, err := encodeEPC(p.EPC)
	if err != nil {
		return BlockEraseResult{}, fmt.Errorf("BlockErase: %w", err)
	}

	data := []byte{enum}
	data = append(data, epcData...)
	data = append(data, byte(p.Mem), p.WordPtr, p.Num)
	data = appendPassword(data, p.Pwd)
	data = appendMask(data, p.MaskAdr, p.MaskLen)

	frame := buildFrame(r.addr, cmdBlockErase, data)

	resp, err := r.exchange(frame,
		txFieldsBlockErase(frame, p),
		cmdBlockErase,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "BlockErase", cmdBlockErase) },
	)
	if err != nil {
		return BlockEraseResult{}, err
	}
	if resp.status != StatusSuccess {
		return BlockEraseResult{}, resp.status
	}
	return BlockEraseResult{}, nil
}

func txFieldsBlockErase(frame []byte, p BlockEraseParams) []debugField {
	fields := txHeaderFields(frame, "BlockErase", cmdBlockErase)
	epcLen := len(p.EPC)
	fb := newFB(frame, 3)
	fb.add(1, "ENum", fmt.Sprintf("%d words = %d bytes", epcLen/2, epcLen))
	if epcLen > 0 {
		fb.add(epcLen, "EPC", epcDetail(p.EPC))
	}
	fb.add(1, "Mem", fmt.Sprintf("%s (0x%02X)", p.Mem, uint8(p.Mem)))
	fb.add(1, "WordPtr", fmt.Sprintf("word address = %d", p.WordPtr))
	fb.add(1, "Num", fmt.Sprintf("word count = %d", p.Num))
	fb.add(4, "Pwd", pwdDetail("access password (0x00000000 = no auth)", p.Pwd))
	fb.add(1, "MaskAdr", fmt.Sprintf("0x%02X", p.MaskAdr))
	fb.add(1, "MaskLen", fmt.Sprintf("%d", p.MaskLen))
	return append(fields, fb.build()...)
}

// BlockWriteParams holds the parameters for the BlockWrite command.
type BlockWriteParams struct {
	EPC     []byte     // tag EPC for selection (nil/empty = match any)
	Mem     MemoryBank
	WordPtr uint8
	Words   []uint16 // WNum derived from len(Words)
	Pwd     [4]byte
	MaskAdr uint8
	MaskLen uint8
}

// BlockWriteResult holds the response data from the BlockWrite command.
type BlockWriteResult struct{}

// BlockWrite writes a block of words to a tag's memory bank (§8.2.16).
//
// TX data: [WNum][ENum][EPC(ENum*2)][Mem][WordPtr][Wdt(WNum*2)][Pwd(4)][MaskAdr][MaskLen]
func (r *Reader) BlockWrite(p BlockWriteParams) (BlockWriteResult, error) {
	enum, epcData, err := encodeEPC(p.EPC)
	if err != nil {
		return BlockWriteResult{}, fmt.Errorf("BlockWrite: %w", err)
	}

	wnum := byte(len(p.Words))
	data := []byte{wnum, enum}
	data = append(data, epcData...)
	data = append(data, byte(p.Mem), p.WordPtr)
	for _, w := range p.Words {
		data = append(data, byte(w>>8), byte(w))
	}
	data = appendPassword(data, p.Pwd)
	data = appendMask(data, p.MaskAdr, p.MaskLen)

	frame := buildFrame(r.addr, cmdBlockWrite, data)

	resp, err := r.exchange(frame,
		txFieldsBlockWrite(frame, p),
		cmdBlockWrite,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "BlockWrite", cmdBlockWrite) },
	)
	if err != nil {
		return BlockWriteResult{}, err
	}
	if resp.status != StatusSuccess {
		return BlockWriteResult{}, resp.status
	}
	return BlockWriteResult{}, nil
}

func txFieldsBlockWrite(frame []byte, p BlockWriteParams) []debugField {
	fields := txHeaderFields(frame, "BlockWrite", cmdBlockWrite)
	epcLen := len(p.EPC)
	fb := newFB(frame, 3)
	fb.add(1, "WNum", fmt.Sprintf("word count = %d (%d bytes)", len(p.Words), len(p.Words)*2))
	fb.add(1, "ENum", fmt.Sprintf("%d words = %d bytes", epcLen/2, epcLen))
	if epcLen > 0 {
		fb.add(epcLen, "EPC", epcDetail(p.EPC))
	}
	fb.add(1, "Mem", fmt.Sprintf("%s (0x%02X)", p.Mem, uint8(p.Mem)))
	fb.add(1, "WordPtr", fmt.Sprintf("word address = %d", p.WordPtr))
	if len(p.Words) > 0 {
		fb.add(len(p.Words)*2, "Wdt", fmt.Sprintf("%d words to write", len(p.Words)))
	}
	fb.add(4, "Pwd", pwdDetail("access password (0x00000000 = no auth)", p.Pwd))
	fb.add(1, "MaskAdr", fmt.Sprintf("0x%02X", p.MaskAdr))
	fb.add(1, "MaskLen", fmt.Sprintf("%d", p.MaskLen))
	return append(fields, fb.build()...)
}

// rxFieldsSimple returns the standard 4-field RX header annotation for commands
// that return no data beyond the status byte.
func rxFieldsSimple(raw []byte, cmdName string, cmdCode byte) []debugField {
	fields := rxHeaderFields(raw, cmdName, cmdCode)
	if len(raw) >= 5 {
		fields = append(fields, debugField{len(raw) - 2, 2, "CRC-16", "checksum (LSB first)"})
	}
	return fields
}
