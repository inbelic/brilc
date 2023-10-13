package bril
import fmt "core:fmt"

// This will provide a control flow graph of a Function ADT

Block :: struct {
    instrs: [dynamic]^Instruction, // constant for testing purposes
    true_next: Label,
    false_next: Label, // "" denotes none
}

func2block_map :: proc(func: Function) -> (block_map: map[Label]Block) {
    label := ".ENTRY"
    label_inc := 0
    block := Block{}
    for _, i in func.instrs[:] {
        instr : ^Instruction = &func.instrs[i]
        if instr.label != "" {
            // Label so we will break here
            block.true_next = instr.label
            block_map[label] = block
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
                block_map[label] = block
                block = Block{}
                label = fmt.tprintf(".B%d", label_inc)
                label_inc = label_inc + 1
            }
        }
    }
    if len(block.instrs) != 0 {
        block.true_next = ".EXIT"
        block_map[label] = block
    }
    return block_map
}

is_terminator :: proc(instr: Instruction) -> bool {
    return instr.op == "br" || instr.op == "jmp" || instr.op == "ret"
}
