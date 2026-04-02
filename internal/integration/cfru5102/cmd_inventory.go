package cfru5102

import "fmt"

const (
	cmdInventory       byte = 0x01
	cmdInventorySingle byte = 0x0F
)

// InventoryParams holds the parameters for the Inventory command.
// This command takes no parameters beyond the reader address already set on the Reader.
type InventoryParams struct{}

// InventoryResult holds the response data from the Inventory command.
type InventoryResult struct {
	EPCs   [][]byte // each entry is one tag's EPC bytes
	Status Status   // 0x01=finished, 0x02=timeout, 0x03=more-data, 0x04=flash-full
}

// Inventory scans for all tags in the RF field and returns their EPCs.
//
// TX frame (§8.2.1):
//
//	[Len=0x04][Adr][Cmd=0x01][CRC_LSB][CRC_MSB]
//
// RX frame:
//
//	[Len][Adr][0x01][Status(0x01–0x04)][Num][EPC1_Len][EPC1_bytes...][EPC2_Len][EPC2_bytes...][CRC_LSB][CRC_MSB]
//
// Status codes 0x01–0x04 all indicate successful inventory with tag data.
func (r *Reader) Inventory(_ InventoryParams) (InventoryResult, error) {
	frame := buildFrame(r.addr, cmdInventory, nil)

	resp, err := r.exchange(frame,
		txHeaderFields(frame, "Inventory", cmdInventory),
		cmdInventory,
		func(raw []byte) []debugField { return rxFieldsInventory(raw) },
	)
	if err != nil {
		return InventoryResult{}, err
	}

	// Status 0x01–0x04 are inventory success codes.
	if !resp.status.IsInventoryStatus() {
		return InventoryResult{}, resp.status
	}

	epcs, err := parseInventoryData(resp.data)
	if err != nil {
		return InventoryResult{}, err
	}

	return InventoryResult{EPCs: epcs, Status: resp.status}, nil
}

// parseInventoryData parses the data portion of an inventory response.
// data[0] = Num, then for each tag: 1-byte EPC_Len, then EPC_Len bytes.
func parseInventoryData(data []byte) ([][]byte, error) {
	if len(data) < 1 {
		return nil, fmt.Errorf("inventory response data too short")
	}
	num := int(data[0])
	epcs := make([][]byte, 0, num)
	pos := 1
	for i := range num {
		if pos >= len(data) {
			return nil, fmt.Errorf("inventory response truncated at tag %d", i)
		}
		epcLen := int(data[pos])
		pos++
		if pos+epcLen > len(data) {
			return nil, fmt.Errorf("EPC %d extends beyond response data", i)
		}
		epc := make([]byte, epcLen)
		copy(epc, data[pos:pos+epcLen])
		epcs = append(epcs, epc)
		pos += epcLen
	}
	return epcs, nil
}

// rxFieldsInventory returns debug field annotations for an Inventory RX frame.
func rxFieldsInventory(raw []byte) []debugField {
	fields := rxHeaderFields(raw, "Inventory", cmdInventory)
	if len(raw) < 7 {
		return fields
	}
	fb := newFB(raw, 4)
	num := int(raw[4])
	fb.add(1, "Num", fmt.Sprintf("tag count = %d", num))
	// Annotate each tag's EPC_Len + EPC bytes if data is available.
	pos := 5
	for i := range num {
		if pos >= len(raw)-2 {
			break
		}
		epcLen := int(raw[pos])
		fb.add(1, fmt.Sprintf("EPC%d_Len", i+1), fmt.Sprintf("%d bytes", epcLen))
		end := pos + 1 + epcLen
		if end > len(raw)-2 {
			end = len(raw) - 2
		}
		actualLen := end - (pos + 1)
		if actualLen > 0 {
			fb.add(actualLen, fmt.Sprintf("EPC%d", i+1), epcDetail(raw[pos+1:pos+1+actualLen]))
		}
		pos += 1 + epcLen
	}
	fb.add(2, "CRC-16", "checksum (LSB first)")
	return append(fields, fb.build()...)
}

// InventorySingleParams holds the parameters for the InventorySingle command.
// This command takes no parameters beyond the reader address already set on the Reader.
type InventorySingleParams struct{}

// InventorySingleResult holds the response data from the InventorySingle command.
type InventorySingleResult struct {
	EPC []byte
}

// InventorySingle reads a single tag from the RF field.
//
// TX frame (§8.2.15):
//
//	[Len=0x04][Adr][Cmd=0x0F][CRC_LSB][CRC_MSB]
//
// RX frame:
//
//	[Len][Adr][0x0F][0x01][0x01][EPC_Len][EPC_bytes...][CRC_LSB][CRC_MSB]
func (r *Reader) InventorySingle(_ InventorySingleParams) (InventorySingleResult, error) {
	frame := buildFrame(r.addr, cmdInventorySingle, nil)

	resp, err := r.exchange(frame,
		txHeaderFields(frame, "InventorySingle", cmdInventorySingle),
		cmdInventorySingle,
		func(raw []byte) []debugField { return rxFieldsInventorySingle(raw) },
	)
	if err != nil {
		return InventorySingleResult{}, err
	}

	if !resp.status.IsInventoryStatus() {
		return InventorySingleResult{}, resp.status
	}

	// data[0] = Num (always 0x01), data[1] = EPC_Len, data[2:] = EPC bytes.
	if len(resp.data) < 2 {
		return InventorySingleResult{}, fmt.Errorf("InventorySingle response data too short: %d bytes", len(resp.data))
	}
	epcLen := int(resp.data[1])
	if len(resp.data) < 2+epcLen {
		return InventorySingleResult{}, fmt.Errorf("InventorySingle EPC truncated: need %d bytes, have %d", epcLen, len(resp.data)-2)
	}
	epc := make([]byte, epcLen)
	copy(epc, resp.data[2:2+epcLen])

	return InventorySingleResult{EPC: epc}, nil
}

// rxFieldsInventorySingle returns debug field annotations for an InventorySingle RX frame.
func rxFieldsInventorySingle(raw []byte) []debugField {
	fields := rxHeaderFields(raw, "InventorySingle", cmdInventorySingle)
	if len(raw) < 8 {
		return fields
	}
	fb := newFB(raw, 4)
	fb.add(1, "Num", "tag count (always 0x01)")
	epcLen := 0
	if len(raw) > 5 {
		epcLen = int(raw[5])
		fb.add(1, "EPC_Len", fmt.Sprintf("%d bytes", epcLen))
	}
	if epcLen > 0 && len(raw) >= 6+epcLen+2 {
		fb.add(epcLen, "EPC", epcDetail(raw[6:6+epcLen]))
	}
	fb.add(2, "CRC-16", "checksum (LSB first)")
	return append(fields, fb.build()...)
}
