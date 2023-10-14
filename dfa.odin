package bril

import slc "core:slice"
import fmt "core:fmt"

// collection of various data flow analysis

// Simple DFA to accumlate all the defined variables
definedDFA :: proc(func: ^Function) {
    block_map := func2block_map(func^)
    defer delete(block_map)
    preds := predeccessor_map(block_map)
    defer delete(preds)

    inputs, outputs : map[Label][dynamic]Variable
    worklist : [dynamic]Label
    defer delete(worklist)
    for key, _ in block_map {
        append(&worklist, key)
        inputs[key] = make([dynamic]Variable, 0)
        outputs[key] = make([dynamic]Variable, 0)
    }

    for len(worklist) > 0 {
        key := pop_front(&worklist)
        if key == "" || key == ".EXIT" { continue }
        // Merge outputs into inputs
        defined_merge(&inputs[key], preds[key][:], outputs)
        // Compute new
        block := block_map[key]
        if defined_transfer(&outputs[key], block, inputs[key][:]) {
            append(&worklist, block.true_next)
            append(&worklist, block.false_next)
        }
    }

    for key, defined in inputs {
        fmt.println(key, "->")
        fmt.println(" inputs:", defined[:])
        fmt.println(" outputs:", outputs[key][:])
    }
}

defined_merge :: proc(inputs: ^[dynamic]Label, preds: []Label, outputs : map[Label][dynamic]Variable) {
    clear(inputs)
    for pred_key in preds {
        for out in outputs[pred_key][:] {
            if !slc.contains(inputs[:], out) {
                append(inputs, out)
            }
        }
    }
}

defined_transfer :: proc(outputs: ^[dynamic]Label, block: Block, inputs: []Label) -> (changed: bool) {
    for label in inputs {
        if !slc.contains(outputs[:], label) {
            append(outputs, label)
            changed = true
        }
    }
    for instr in block.instrs {
        if instr.dest != "" && !slc.contains(outputs[:], instr.dest) {
            append(outputs, instr.dest)
            changed = true
        }
    }
    return changed
}
