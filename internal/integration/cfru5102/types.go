package cfru5102

import (
	"encoding/hex"
	"fmt"
)

// MemoryBank identifies which memory bank to operate on.
type MemoryBank uint8

const (
	MemoryBankReserved MemoryBank = 0x00
	MemoryBankEPC      MemoryBank = 0x01
	MemoryBankTID      MemoryBank = 0x02
	MemoryBankUser     MemoryBank = 0x03
)

func (m MemoryBank) String() string {
	switch m {
	case MemoryBankReserved:
		return "Reserved"
	case MemoryBankEPC:
		return "EPC"
	case MemoryBankTID:
		return "TID"
	case MemoryBankUser:
		return "User"
	default:
		return fmt.Sprintf("MemoryBank(0x%02X)", uint8(m))
	}
}

// LockTarget identifies which memory region or password to lock.
type LockTarget uint8

const (
	LockTargetKillPwd  LockTarget = 0x00
	LockTargetAccessPwd LockTarget = 0x01
	LockTargetEPC      LockTarget = 0x02
	LockTargetTID      LockTarget = 0x03
	LockTargetUser     LockTarget = 0x04
)

func (t LockTarget) String() string {
	switch t {
	case LockTargetKillPwd:
		return "KillPassword"
	case LockTargetAccessPwd:
		return "AccessPassword"
	case LockTargetEPC:
		return "EPC"
	case LockTargetTID:
		return "TID"
	case LockTargetUser:
		return "User"
	default:
		return fmt.Sprintf("LockTarget(0x%02X)", uint8(t))
	}
}

// LockAction specifies the lock operation.
// For password targets (KillPwd, AccessPwd): 0x00=rw-any, 0x01=perm-rw, 0x02=rw-secured, 0x03=never-rw.
// For memory targets (EPC, TID, User): 0x00=w-any, 0x01=perm-w, 0x02=w-secured, 0x03=never-w.
type LockAction uint8

const (
	LockActionRWAny      LockAction = 0x00
	LockActionPermRW     LockAction = 0x01
	LockActionRWSecured  LockAction = 0x02
	LockActionNeverRW    LockAction = 0x03
)

func (a LockAction) String() string {
	switch a {
	case LockActionRWAny:
		return "RW-Any"
	case LockActionPermRW:
		return "Perm-RW"
	case LockActionRWSecured:
		return "RW-Secured"
	case LockActionNeverRW:
		return "Never-RW"
	default:
		return fmt.Sprintf("LockAction(0x%02X)", uint8(a))
	}
}

// BaudRate encodes the serial baud rate setting.
type BaudRate uint8

const (
	BaudRate9600   BaudRate = 0
	BaudRate19200  BaudRate = 1
	BaudRate38400  BaudRate = 2
	BaudRate43000  BaudRate = 3
	BaudRate56000  BaudRate = 4
	BaudRate57600  BaudRate = 5
	BaudRate115200 BaudRate = 6
)

func (b BaudRate) String() string {
	switch b {
	case BaudRate9600:
		return "9600"
	case BaudRate19200:
		return "19200"
	case BaudRate38400:
		return "38400"
	case BaudRate43000:
		return "43000"
	case BaudRate56000:
		return "56000"
	case BaudRate57600:
		return "57600"
	case BaudRate115200:
		return "115200"
	default:
		return fmt.Sprintf("BaudRate(%d)", uint8(b))
	}
}

// encodeEPC validates an EPC byte slice and returns the ENum (len/2) and the EPC bytes.
// EPC must be non-empty, even-length, and at most 30 bytes (15 words).
// If epc is nil or empty, returns ENum=0 and nil data (match any tag).
func encodeEPC(epc []byte) (enum byte, data []byte, err error) {
	if len(epc) == 0 {
		return 0, nil, nil
	}
	if len(epc)%2 != 0 {
		return 0, nil, fmt.Errorf("EPC length %d is odd; must be even", len(epc))
	}
	if len(epc) > 30 {
		return 0, nil, fmt.Errorf("EPC length %d exceeds maximum of 30 bytes (15 words)", len(epc))
	}
	return byte(len(epc) / 2), epc, nil
}

// appendEPC appends the ENum byte followed by EPC bytes to buf.
func appendEPC(buf, epc []byte) []byte {
	enum, data, _ := encodeEPC(epc) // caller already validated
	buf = append(buf, enum)
	buf = append(buf, data...)
	return buf
}

// appendPassword appends 4 password bytes to buf.
func appendPassword(buf []byte, pwd [4]byte) []byte {
	return append(buf, pwd[0], pwd[1], pwd[2], pwd[3])
}

// appendMask appends the MaskAdr and MaskLen bytes to buf.
func appendMask(buf []byte, maskAdr, maskLen byte) []byte {
	return append(buf, maskAdr, maskLen)
}

// fieldBuilder tracks offsets for building debug field annotations in variable-length frames.
type fieldBuilder struct {
	offset int
	frame  []byte
	out    []debugField
}

// newFB creates a new fieldBuilder starting at startOffset within frame.
func newFB(frame []byte, startOffset int) *fieldBuilder {
	return &fieldBuilder{offset: startOffset, frame: frame}
}

// add appends a debugField of the given length at the current offset, then advances the offset.
func (fb *fieldBuilder) add(length int, name, detail string) *fieldBuilder {
	fb.out = append(fb.out, debugField{fb.offset, length, name, detail})
	fb.offset += length
	return fb
}

// build returns the accumulated debug fields.
func (fb *fieldBuilder) build() []debugField {
	return fb.out
}

// epcDetail returns a human-readable string describing an EPC field.
func epcDetail(epc []byte) string {
	if len(epc) == 0 {
		return "EPC (0 words = 0 bytes): match any"
	}
	return fmt.Sprintf("EPC (%d words = %d bytes): %s", len(epc)/2, len(epc), hex.EncodeToString(epc))
}

// pwdDetail returns a human-readable string describing a password field.
func pwdDetail(label string, pwd [4]byte) string {
	return fmt.Sprintf("%s (0x%08X)", label, uint32(pwd[0])<<24|uint32(pwd[1])<<16|uint32(pwd[2])<<8|uint32(pwd[3]))
}

// txHeaderFields returns the 4 standard TX header debug fields (Len, Adr, Cmd, CRC-16).
func txHeaderFields(frame []byte, cmdName string, cmdCode byte) []debugField {
	crc := crc16(frame[:len(frame)-2])
	return []debugField{
		{0, 1, "Len", fmt.Sprintf("frame length (excl. self) = %d", frame[0])},
		{1, 1, "Adr", fmt.Sprintf("reader address = 0x%02X", frame[1])},
		{2, 1, "Cmd", fmt.Sprintf("%s (0x%02X)", cmdName, cmdCode)},
		{len(frame) - 2, 2, "CRC-16", fmt.Sprintf("0x%04X (LSB first)", crc)},
	}
}

// rxHeaderFields returns the 4 standard RX header debug fields (Len, Adr, reCmd, Status).
func rxHeaderFields(raw []byte, cmdName string, cmdCode byte) []debugField {
	return []debugField{
		{0, 1, "Len", "frame length (excl. self)"},
		{1, 1, "Adr", "reader address (echo)"},
		{2, 1, "reCmd", fmt.Sprintf("echoed command = %s (0x%02X)", cmdName, cmdCode)},
		{3, 1, "Status", statusDetail(raw, 3)},
	}
}
