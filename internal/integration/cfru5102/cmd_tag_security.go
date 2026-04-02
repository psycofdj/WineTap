package cfru5102

import "fmt"

const (
	cmdKillTag                 byte = 0x05
	cmdLock                    byte = 0x06
	cmdReadProtect             byte = 0x08
	cmdReadProtectWithoutEPC   byte = 0x09
	cmdResetReadProtect        byte = 0x0A
	cmdCheckReadProtect        byte = 0x0B
	cmdEASAlarm                byte = 0x0C
	cmdCheckEASAlarm           byte = 0x0D
	cmdUserBlockLock           byte = 0x0E
)

// KillTagParams holds the parameters for the KillTag command.
type KillTagParams struct {
	EPC     []byte // tag EPC for selection (nil/empty = match any)
	KillPwd [4]byte
	MaskAdr uint8
	MaskLen uint8
}

// KillTagResult holds the response data from the KillTag command.
type KillTagResult struct{}

// KillTag permanently kills a tag (§8.2.5).
//
// TX data: [ENum][EPC(ENum*2)][KillPwd(4)][MaskAdr][MaskLen]
func (r *Reader) KillTag(p KillTagParams) (KillTagResult, error) {
	enum, epcData, err := encodeEPC(p.EPC)
	if err != nil {
		return KillTagResult{}, fmt.Errorf("KillTag: %w", err)
	}

	data := []byte{enum}
	data = append(data, epcData...)
	data = appendPassword(data, p.KillPwd)
	data = appendMask(data, p.MaskAdr, p.MaskLen)

	frame := buildFrame(r.addr, cmdKillTag, data)

	resp, err := r.exchange(frame,
		txFieldsKillTag(frame, p),
		cmdKillTag,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "KillTag", cmdKillTag) },
	)
	if err != nil {
		return KillTagResult{}, err
	}
	if resp.status != StatusSuccess {
		return KillTagResult{}, resp.status
	}
	return KillTagResult{}, nil
}

func txFieldsKillTag(frame []byte, p KillTagParams) []debugField {
	fields := txHeaderFields(frame, "KillTag", cmdKillTag)
	epcLen := len(p.EPC)
	fb := newFB(frame, 3)
	fb.add(1, "ENum", fmt.Sprintf("%d words = %d bytes", epcLen/2, epcLen))
	if epcLen > 0 {
		fb.add(epcLen, "EPC", epcDetail(p.EPC))
	}
	fb.add(4, "KillPwd", pwdDetail("kill password", p.KillPwd))
	fb.add(1, "MaskAdr", fmt.Sprintf("0x%02X", p.MaskAdr))
	fb.add(1, "MaskLen", fmt.Sprintf("%d", p.MaskLen))
	return append(fields, fb.build()...)
}

// LockParams holds the parameters for the Lock command.
type LockParams struct {
	EPC     []byte // tag EPC for selection (nil/empty = match any)
	Target  LockTarget
	Action  LockAction
	Pwd     [4]byte
	MaskAdr uint8
	MaskLen uint8
}

// LockResult holds the response data from the Lock command.
type LockResult struct{}

// Lock sets the lock state of a tag memory region or password (§8.2.6).
//
// TX data: [ENum][EPC(ENum*2)][Select][SetProtect][Pwd(4)][MaskAdr][MaskLen]
func (r *Reader) Lock(p LockParams) (LockResult, error) {
	enum, epcData, err := encodeEPC(p.EPC)
	if err != nil {
		return LockResult{}, fmt.Errorf("Lock: %w", err)
	}

	data := []byte{enum}
	data = append(data, epcData...)
	data = append(data, byte(p.Target), byte(p.Action))
	data = appendPassword(data, p.Pwd)
	data = appendMask(data, p.MaskAdr, p.MaskLen)

	frame := buildFrame(r.addr, cmdLock, data)

	resp, err := r.exchange(frame,
		txFieldsLock(frame, p),
		cmdLock,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "Lock", cmdLock) },
	)
	if err != nil {
		return LockResult{}, err
	}
	if resp.status != StatusSuccess {
		return LockResult{}, resp.status
	}
	return LockResult{}, nil
}

func txFieldsLock(frame []byte, p LockParams) []debugField {
	fields := txHeaderFields(frame, "Lock", cmdLock)
	epcLen := len(p.EPC)
	fb := newFB(frame, 3)
	fb.add(1, "ENum", fmt.Sprintf("%d words = %d bytes", epcLen/2, epcLen))
	if epcLen > 0 {
		fb.add(epcLen, "EPC", epcDetail(p.EPC))
	}
	fb.add(1, "Select", fmt.Sprintf("lock target: %s (0x%02X)", p.Target, uint8(p.Target)))
	fb.add(1, "SetProtect", fmt.Sprintf("lock action: %s (0x%02X)", p.Action, uint8(p.Action)))
	fb.add(4, "Pwd", pwdDetail("access password (0x00000000 = no auth)", p.Pwd))
	fb.add(1, "MaskAdr", fmt.Sprintf("0x%02X", p.MaskAdr))
	fb.add(1, "MaskLen", fmt.Sprintf("%d", p.MaskLen))
	return append(fields, fb.build()...)
}

// ReadProtectParams holds the parameters for the ReadProtect command.
type ReadProtectParams struct {
	EPC     []byte // tag EPC for selection (nil/empty = match any)
	Pwd     [4]byte
	MaskAdr uint8
	MaskLen uint8
}

// ReadProtectResult holds the response data from the ReadProtect command.
type ReadProtectResult struct{}

// ReadProtect sets read protection on a tag with EPC selection (§8.2.8).
//
// TX data: [ENum][EPC(ENum*2)][Pwd(4)][MaskAdr][MaskLen]
func (r *Reader) ReadProtect(p ReadProtectParams) (ReadProtectResult, error) {
	enum, epcData, err := encodeEPC(p.EPC)
	if err != nil {
		return ReadProtectResult{}, fmt.Errorf("ReadProtect: %w", err)
	}

	data := []byte{enum}
	data = append(data, epcData...)
	data = appendPassword(data, p.Pwd)
	data = appendMask(data, p.MaskAdr, p.MaskLen)

	frame := buildFrame(r.addr, cmdReadProtect, data)

	resp, err := r.exchange(frame,
		txFieldsReadProtect(frame, p),
		cmdReadProtect,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "ReadProtect", cmdReadProtect) },
	)
	if err != nil {
		return ReadProtectResult{}, err
	}
	if resp.status != StatusSuccess {
		return ReadProtectResult{}, resp.status
	}
	return ReadProtectResult{}, nil
}

func txFieldsReadProtect(frame []byte, p ReadProtectParams) []debugField {
	fields := txHeaderFields(frame, "ReadProtect", cmdReadProtect)
	epcLen := len(p.EPC)
	fb := newFB(frame, 3)
	fb.add(1, "ENum", fmt.Sprintf("%d words = %d bytes", epcLen/2, epcLen))
	if epcLen > 0 {
		fb.add(epcLen, "EPC", epcDetail(p.EPC))
	}
	fb.add(4, "Pwd", pwdDetail("access password (0x00000000 = no auth)", p.Pwd))
	fb.add(1, "MaskAdr", fmt.Sprintf("0x%02X", p.MaskAdr))
	fb.add(1, "MaskLen", fmt.Sprintf("%d", p.MaskLen))
	return append(fields, fb.build()...)
}

// ReadProtectWithoutEPCParams holds the parameters for the ReadProtectWithoutEPC command.
type ReadProtectWithoutEPCParams struct {
	Pwd [4]byte
}

// ReadProtectWithoutEPCResult holds the response data from the ReadProtectWithoutEPC command.
type ReadProtectWithoutEPCResult struct{}

// ReadProtectWithoutEPC sets read protection on a random tag in the field (§8.2.9).
//
// TX frame: [0x08][Adr][0x09][Pwd(4)][CRC_LSB][CRC_MSB]
func (r *Reader) ReadProtectWithoutEPC(p ReadProtectWithoutEPCParams) (ReadProtectWithoutEPCResult, error) {
	data := make([]byte, 0, 4)
	data = appendPassword(data, p.Pwd)

	frame := buildFrame(r.addr, cmdReadProtectWithoutEPC, data)

	resp, err := r.exchange(frame,
		txFieldsReadProtectWithoutEPC(frame, p),
		cmdReadProtectWithoutEPC,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "ReadProtectWithoutEPC", cmdReadProtectWithoutEPC) },
	)
	if err != nil {
		return ReadProtectWithoutEPCResult{}, err
	}
	if resp.status != StatusSuccess {
		return ReadProtectWithoutEPCResult{}, resp.status
	}
	return ReadProtectWithoutEPCResult{}, nil
}

func txFieldsReadProtectWithoutEPC(frame []byte, p ReadProtectWithoutEPCParams) []debugField {
	fields := txHeaderFields(frame, "ReadProtectWithoutEPC", cmdReadProtectWithoutEPC)
	fb := newFB(frame, 3)
	fb.add(4, "Pwd", pwdDetail("access password (0x00000000 = no auth)", p.Pwd))
	return append(fields, fb.build()...)
}

// ResetReadProtectParams holds the parameters for the ResetReadProtect command.
type ResetReadProtectParams struct {
	Pwd [4]byte
}

// ResetReadProtectResult holds the response data from the ResetReadProtect command.
type ResetReadProtectResult struct{}

// ResetReadProtect removes read protection from a tag in the field (§8.2.10).
//
// TX frame: [0x08][Adr][0x0A][Pwd(4)][CRC_LSB][CRC_MSB]
func (r *Reader) ResetReadProtect(p ResetReadProtectParams) (ResetReadProtectResult, error) {
	data := make([]byte, 0, 4)
	data = appendPassword(data, p.Pwd)

	frame := buildFrame(r.addr, cmdResetReadProtect, data)

	resp, err := r.exchange(frame,
		txFieldsResetReadProtect(frame, p),
		cmdResetReadProtect,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "ResetReadProtect", cmdResetReadProtect) },
	)
	if err != nil {
		return ResetReadProtectResult{}, err
	}
	if resp.status != StatusSuccess {
		return ResetReadProtectResult{}, resp.status
	}
	return ResetReadProtectResult{}, nil
}

func txFieldsResetReadProtect(frame []byte, p ResetReadProtectParams) []debugField {
	fields := txHeaderFields(frame, "ResetReadProtect", cmdResetReadProtect)
	fb := newFB(frame, 3)
	fb.add(4, "Pwd", pwdDetail("access password (0x00000000 = no auth)", p.Pwd))
	return append(fields, fb.build()...)
}

// CheckReadProtectParams holds the parameters for the CheckReadProtect command.
type CheckReadProtectParams struct{}

// CheckReadProtectResult holds the response data from the CheckReadProtect command.
type CheckReadProtectResult struct {
	Protected bool // true if the tag is read-protected
}

// CheckReadProtect checks whether a tag in the field has read protection set (§8.2.11).
//
// TX frame: [0x04][Adr][0x0B][CRC_LSB][CRC_MSB]
//
// RX data: [ReadPro] — 0x00 = protected, 0x01 = unprotected.
func (r *Reader) CheckReadProtect(_ CheckReadProtectParams) (CheckReadProtectResult, error) {
	frame := buildFrame(r.addr, cmdCheckReadProtect, nil)

	resp, err := r.exchange(frame,
		txHeaderFields(frame, "CheckReadProtect", cmdCheckReadProtect),
		cmdCheckReadProtect,
		func(raw []byte) []debugField { return rxFieldsCheckReadProtect(raw) },
	)
	if err != nil {
		return CheckReadProtectResult{}, err
	}
	if resp.status != StatusSuccess {
		return CheckReadProtectResult{}, resp.status
	}
	if len(resp.data) < 1 {
		return CheckReadProtectResult{}, fmt.Errorf("CheckReadProtect: response data too short")
	}
	return CheckReadProtectResult{Protected: resp.data[0] == 0x00}, nil
}

func rxFieldsCheckReadProtect(raw []byte) []debugField {
	fields := rxHeaderFields(raw, "CheckReadProtect", cmdCheckReadProtect)
	if len(raw) >= 7 {
		protected := "unprotected (0x01)"
		if len(raw) > 4 && raw[4] == 0x00 {
			protected = "protected (0x00)"
		}
		fields = append(fields,
			debugField{4, 1, "ReadPro", protected},
			debugField{5, 2, "CRC-16", "checksum (LSB first)"},
		)
	}
	return fields
}

// EASAlarmParams holds the parameters for the EASAlarm command.
type EASAlarmParams struct {
	EPC     []byte // tag EPC for selection (nil/empty = match any)
	Pwd     [4]byte
	Set     bool  // true = set EAS alarm, false = reset EAS alarm
	MaskAdr uint8
	MaskLen uint8
}

// EASAlarmResult holds the response data from the EASAlarm command.
type EASAlarmResult struct{}

// EASAlarm sets or resets the EAS alarm flag on a tag (§8.2.12).
//
// TX data: [ENum][EPC(ENum*2)][Pwd(4)][EAS][MaskAdr][MaskLen]
// EAS: bit0=1 to set, bit0=0 to reset.
func (r *Reader) EASAlarm(p EASAlarmParams) (EASAlarmResult, error) {
	enum, epcData, err := encodeEPC(p.EPC)
	if err != nil {
		return EASAlarmResult{}, fmt.Errorf("EASAlarm: %w", err)
	}

	eas := byte(0x00)
	if p.Set {
		eas = 0x01
	}

	data := []byte{enum}
	data = append(data, epcData...)
	data = appendPassword(data, p.Pwd)
	data = append(data, eas)
	data = appendMask(data, p.MaskAdr, p.MaskLen)

	frame := buildFrame(r.addr, cmdEASAlarm, data)

	resp, err := r.exchange(frame,
		txFieldsEASAlarm(frame, p),
		cmdEASAlarm,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "EASAlarm", cmdEASAlarm) },
	)
	if err != nil {
		return EASAlarmResult{}, err
	}
	if resp.status != StatusSuccess {
		return EASAlarmResult{}, resp.status
	}
	return EASAlarmResult{}, nil
}

func txFieldsEASAlarm(frame []byte, p EASAlarmParams) []debugField {
	fields := txHeaderFields(frame, "EASAlarm", cmdEASAlarm)
	epcLen := len(p.EPC)
	fb := newFB(frame, 3)
	fb.add(1, "ENum", fmt.Sprintf("%d words = %d bytes", epcLen/2, epcLen))
	if epcLen > 0 {
		fb.add(epcLen, "EPC", epcDetail(p.EPC))
	}
	fb.add(4, "Pwd", pwdDetail("access password (0x00000000 = no auth)", p.Pwd))
	easDesc := "reset EAS (0x00)"
	if p.Set {
		easDesc = "set EAS (0x01)"
	}
	fb.add(1, "EAS", easDesc)
	fb.add(1, "MaskAdr", fmt.Sprintf("0x%02X", p.MaskAdr))
	fb.add(1, "MaskLen", fmt.Sprintf("%d", p.MaskLen))
	return append(fields, fb.build()...)
}

// CheckEASAlarmParams holds the parameters for the CheckEASAlarm command.
type CheckEASAlarmParams struct{}

// CheckEASAlarmResult holds the response data from the CheckEASAlarm command.
type CheckEASAlarmResult struct {
	Alarming bool // true if the EAS alarm is active
}

// CheckEASAlarm checks whether the EAS alarm is active (§8.2.13).
//
// TX frame: [0x04][Adr][0x0D][CRC_LSB][CRC_MSB]
//
// Success (StatusSuccess) means alarm is active; StatusNoTag means no alarm.
func (r *Reader) CheckEASAlarm(_ CheckEASAlarmParams) (CheckEASAlarmResult, error) {
	frame := buildFrame(r.addr, cmdCheckEASAlarm, nil)

	resp, err := r.exchange(frame,
		txHeaderFields(frame, "CheckEASAlarm", cmdCheckEASAlarm),
		cmdCheckEASAlarm,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "CheckEASAlarm", cmdCheckEASAlarm) },
	)
	if err != nil {
		return CheckEASAlarmResult{}, err
	}

	switch resp.status {
	case StatusSuccess:
		return CheckEASAlarmResult{Alarming: true}, nil
	case StatusNoTag:
		return CheckEASAlarmResult{Alarming: false}, nil
	default:
		return CheckEASAlarmResult{}, resp.status
	}
}

// UserBlockLockParams holds the parameters for the UserBlockLock command.
type UserBlockLockParams struct {
	EPC        []byte // tag EPC for selection (nil/empty = match any)
	Pwd        [4]byte
	WrdPointer uint8
	MaskAdr    uint8
	MaskLen    uint8
}

// UserBlockLockResult holds the response data from the UserBlockLock command.
type UserBlockLockResult struct{}

// UserBlockLock locks a specific word in the user memory bank (§8.2.14).
//
// TX data: [ENum][EPC(ENum*2)][Pwd(4)][WrdPointer][MaskAdr][MaskLen]
func (r *Reader) UserBlockLock(p UserBlockLockParams) (UserBlockLockResult, error) {
	enum, epcData, err := encodeEPC(p.EPC)
	if err != nil {
		return UserBlockLockResult{}, fmt.Errorf("UserBlockLock: %w", err)
	}

	data := []byte{enum}
	data = append(data, epcData...)
	data = appendPassword(data, p.Pwd)
	data = append(data, p.WrdPointer)
	data = appendMask(data, p.MaskAdr, p.MaskLen)

	frame := buildFrame(r.addr, cmdUserBlockLock, data)

	resp, err := r.exchange(frame,
		txFieldsUserBlockLock(frame, p),
		cmdUserBlockLock,
		func(raw []byte) []debugField { return rxFieldsSimple(raw, "UserBlockLock", cmdUserBlockLock) },
	)
	if err != nil {
		return UserBlockLockResult{}, err
	}
	if resp.status != StatusSuccess {
		return UserBlockLockResult{}, resp.status
	}
	return UserBlockLockResult{}, nil
}

func txFieldsUserBlockLock(frame []byte, p UserBlockLockParams) []debugField {
	fields := txHeaderFields(frame, "UserBlockLock", cmdUserBlockLock)
	epcLen := len(p.EPC)
	fb := newFB(frame, 3)
	fb.add(1, "ENum", fmt.Sprintf("%d words = %d bytes", epcLen/2, epcLen))
	if epcLen > 0 {
		fb.add(epcLen, "EPC", epcDetail(p.EPC))
	}
	fb.add(4, "Pwd", pwdDetail("access password (0x00000000 = no auth)", p.Pwd))
	fb.add(1, "WrdPointer", fmt.Sprintf("word address = %d", p.WrdPointer))
	fb.add(1, "MaskAdr", fmt.Sprintf("0x%02X", p.MaskAdr))
	fb.add(1, "MaskLen", fmt.Sprintf("%d", p.MaskLen))
	return append(fields, fb.build()...)
}
