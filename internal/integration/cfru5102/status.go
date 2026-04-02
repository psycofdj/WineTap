package cfru5102

import "fmt"

// Status is the one-byte result code returned by the reader in every response frame.
// See datasheet section 5 for the full table.
type Status byte

const (
	StatusSuccess                   Status = 0x00
	StatusInventoryFinished         Status = 0x01 // inventory complete, tags returned
	StatusInventoryScanTimeOverflow Status = 0x02 // scan time expired before all tags read
	StatusInventoryMoreData         Status = 0x03 // data split across multiple responses
	StatusInventoryFlashFull        Status = 0x04 // reader flash full
	StatusAccessPasswordError       Status = 0x05
	StatusKillTagError              Status = 0x09
	StatusKillPasswordZero          Status = 0x0A
	StatusTagNotSupportCommand      Status = 0x0B
	StatusAccessPasswordZero        Status = 0x0C
	StatusTagAlreadyProtected       Status = 0x0D
	StatusTagNotProtected           Status = 0x0E
	StatusLockedBytesWriteFail      Status = 0x10
	StatusCannotLock                Status = 0x11
	StatusAlreadyLocked             Status = 0x12
	StatusSaveFail                  Status = 0x13
	StatusCannotAdjust              Status = 0x14
	Status6BInventoryFinished       Status = 0x15
	Status6BScanTimeOverflow        Status = 0x16
	Status6BInventoryMoreData       Status = 0x17
	Status6BInventoryFlashFull      Status = 0x18
	StatusNotSupportOrPasswordZero  Status = 0x19
	StatusCommandExecuteError       Status = 0xF9
	StatusPoorCommunication         Status = 0xFA
	StatusNoTag                     Status = 0xFB
	StatusTagReturnedErrorCode      Status = 0xFC
	StatusCommandLengthWrong        Status = 0xFD
	StatusIllegalCommand            Status = 0xFE
	StatusParameterError            Status = 0xFF
)

func (s Status) String() string {
	switch s {
	case StatusSuccess:
		return "Success"
	case StatusInventoryFinished:
		return "InventoryFinished"
	case StatusInventoryScanTimeOverflow:
		return "InventoryScanTimeOverflow"
	case StatusInventoryMoreData:
		return "InventoryMoreData"
	case StatusInventoryFlashFull:
		return "InventoryFlashFull"
	case StatusAccessPasswordError:
		return "AccessPasswordError"
	case StatusKillTagError:
		return "KillTagError"
	case StatusKillPasswordZero:
		return "KillPasswordZero"
	case StatusTagNotSupportCommand:
		return "TagNotSupportCommand"
	case StatusAccessPasswordZero:
		return "AccessPasswordZero"
	case StatusTagAlreadyProtected:
		return "TagAlreadyProtected"
	case StatusTagNotProtected:
		return "TagNotProtected"
	case StatusLockedBytesWriteFail:
		return "LockedBytesWriteFail"
	case StatusCannotLock:
		return "CannotLock"
	case StatusAlreadyLocked:
		return "AlreadyLocked"
	case StatusSaveFail:
		return "SaveFail"
	case StatusCannotAdjust:
		return "CannotAdjust"
	case Status6BInventoryFinished:
		return "6BInventoryFinished"
	case Status6BScanTimeOverflow:
		return "6BScanTimeOverflow"
	case Status6BInventoryMoreData:
		return "6BInventoryMoreData"
	case Status6BInventoryFlashFull:
		return "6BInventoryFlashFull"
	case StatusNotSupportOrPasswordZero:
		return "NotSupportOrPasswordZero"
	case StatusCommandExecuteError:
		return "CommandExecuteError"
	case StatusPoorCommunication:
		return "PoorCommunication"
	case StatusNoTag:
		return "NoTag"
	case StatusTagReturnedErrorCode:
		return "TagReturnedErrorCode"
	case StatusCommandLengthWrong:
		return "CommandLengthWrong"
	case StatusIllegalCommand:
		return "IllegalCommand"
	case StatusParameterError:
		return "ParameterError"
	default:
		return fmt.Sprintf("Unknown(0x%02X)", byte(s))
	}
}

// Error implements the error interface so Status values can be returned as errors.
func (s Status) Error() string {
	return fmt.Sprintf("reader error: %s (0x%02X)", s.String(), byte(s))
}

// IsInventoryStatus reports whether s is one of the inventory-family status codes
// (0x01–0x04) that carry tag data alongside a non-zero status.
func (s Status) IsInventoryStatus() bool {
	return s >= StatusInventoryFinished && s <= StatusInventoryFlashFull
}
