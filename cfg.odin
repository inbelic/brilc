package bril

import fmt "core:fmt"

// This will provide a control flow graph of a Function ADT

Block :: struct {
    instrs: [dynamic]^Instruction, // constant for testing purposes
    true_next: Label,
    false_next: Label, // "" denotes none
}

BlockMap :: map[Label]Block

func2block_map :: proc(func: Function) -> (block_map: BlockMap) {
    entry_block := true
    label := ".ENTRY"
    label_inc := 0
    block := Block{}
    for instr in func.instrs[:] {
        if instr.label != "" {
            // Label so we will break here
            if len(block.instrs) != 0 || entry_block {
                block.true_next = instr.label
                block_map[label] = block
                entry_block = false
            }
            label = instr.label
            block = Block{}
        } else {
            append(&block.instrs, instr)
            if is_terminator(instr^) {
                switch instr.op {
                    case "jmp": block.true_next = instr.labels[0]
                    case "br": {
                        block.true_next = instr.labels[0]
                        block.false_next = instr.labels[1]
                    }
                    case "ret": {
                        block.true_next = ".EXIT"
                    }
                    case:
                }
                if len(block.instrs) != 0 {
                    block_map[label] = block
                    entry_block = false
                }
                block = Block{}
                label = fmt.tprintf(".B%d", label_inc)
                label_inc = label_inc + 1
            }
        }
    }
    if len(block.instrs) != 0 {
        block.true_next = ".EXIT"
        block_map[label] = block
        entry_block = false
    }
    return block_map
}

is_terminator :: proc(instr: Instruction) -> bool {
    return instr.op == "br" || instr.op == "jmp" || instr.op == "ret"
}

predeccessor_map :: proc(block_map: BlockMap) -> (preds: map[Label][dynamic]Label) {
    for key, _ in block_map {
        preds[key] = make([dynamic]Variable, 0)
    }
    for key, block in block_map {
        append(&preds[block.true_next], key)
        append(&preds[block.false_next], key)
    }
    return preds
}
