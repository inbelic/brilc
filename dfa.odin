package bril

import slc "core:slice"
import fmt "core:fmt"

// collection of various data flow analysis

// Generalized worklist wrapper
worklist_forward :: proc(func: ^Function, init: proc() -> $T,
                        merge: proc(^T, []Label, map[Label]T),
                        transfer: proc(^T, Block, T) -> bool) {
    block_map := func2block_map(func^)
    defer delete(block_map)
    preds := predeccessor_map(block_map)
    defer delete(preds)

    inputs, outputs : map[Label]T
    worklist : [dynamic]Label
    defer delete(worklist)
    for key, _ in block_map {
        append(&worklist, key)
        inputs[key] = init()
        outputs[key] = init()
    }

    for len(worklist) > 0 {
        key := pop_front(&worklist)
        if key == "" || key == ".EXIT" { continue }
        // Merge outputs into inputs
        merge(&inputs[key], preds[key][:], outputs)
        // Compute new
        block := block_map[key]
        if transfer(&outputs[key], block, inputs[key]) {
            append(&worklist, block.true_next)
            append(&worklist, block.false_next)
        }
    }

    for key, inps in inputs {
        fmt.println(key, "->")
        fmt.println(" inputs:", inps[:])
        fmt.println(" outputs:", outputs[key][:])
    }
}

// Generalized worklist wrapper that iterates backwards
worklist_backward :: proc(func: ^Function, init: proc() -> $T,
                          merge: proc(^T, []Label, map[Label]T),
                          transfer: proc(^T, Block, T) -> bool) {
    block_map := func2block_map(func^)
    defer delete(block_map)
    preds := predeccessor_map(block_map)
    defer delete(preds)

    inputs, outputs : map[Label]T
    worklist : [dynamic]Label
    defer delete(worklist)
    for key, _ in block_map {
        append(&worklist, key)
        inputs[key] = init()
        outputs[key] = init()
    }

    for len(worklist) > 0 {
        key := pop_front(&worklist)
        block := block_map[key]
        if key == "" || key == ".EXIT" { continue }
        // Merge outputs into inputs
        succs : [2]Label
        used := 0
        if block.true_next != "" {
            succs[0] = block.true_next
            used += 1
        }
        if block.false_next != "" {
            succs[1] = block.false_next
            used += 1
        }
        merge(&outputs[key], succs[:used], inputs)
        // Compute new
        if transfer(&inputs[key], block, outputs[key]) {
            for pred in preds[key][:] {
                append(&worklist, pred)
            }
        }
    }

    for key, inps in inputs {
        fmt.println(key, "->")
        fmt.println(" inputs:", inps[:])
        fmt.println(" outputs:", outputs[key][:])
    }
}

// Here we implement various components to plug into the worklist algorithm

// INIT Helpers:
null_vec :: proc() -> [dynamic]Label {
    return make([dynamic]Label, 0)
}

// MERGE Helpers:
union_merge :: proc(inputs: ^[dynamic]Label, preds: []Label, outputs: map[Label][dynamic]Variable) {
    clear(inputs)
    for pred_key in preds {
        for out in outputs[pred_key][:] {
            if !slc.contains(inputs[:], out) {
                append(inputs, out)
            }
        }
    }
}


// TRANSFER Helpers:
defined_transfer :: proc(outputs: ^[dynamic]Label, block: Block, inputs: [dynamic]Label) -> (changed: bool) {
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

livevar_transfer :: proc(outputs: ^[dynamic]Label, block: Block, inputs: [dynamic]Label) -> (changed: bool) {
    adds, dels: [dynamic]Label
    defer delete(adds); delete(dels)
    for label in inputs {
        if !slc.contains(outputs[:], label) {
            append(outputs, label)
            append(&adds, label)
        }
    }
    instrs := make([dynamic]^Instruction, len(block.instrs))
    defer delete(instrs)
    copy(instrs[:], block.instrs[:])
    slc.reverse(instrs[:])
    for instr in instrs {
        if instr.dest != "" {
            idx, found := slc.linear_search(outputs[:], instr.dest)
            if found {
                unordered_remove(outputs, idx)
                append(&dels, instr.dest)
            }
        }
        for arg in instr.args {
            if !slc.contains(outputs[:], arg) {
                append(outputs, arg)
                append(&adds, arg)
            }
        }
    }

    for del, i in dels[:] {
        idx, found := slc.linear_search(adds[:], del)
        if found {
            unordered_remove(&adds, idx)
        } else {
            return true
        }
    }
    return len(adds) > 0
}

cprop_transfer :: proc(outputs: ^[dynamic]Label, block: Block, inputs: [dynamic]Label) -> (changed: bool) {
    for label in inputs {
        if !slc.contains(outputs[:], label) {
            append(outputs, label)
            changed = true
        }
    }
    for instr in block.instrs {
        if instr.op == "const" {
            if !slc.contains(outputs[:], instr.dest) {
                append(outputs, instr.dest)
            }
        } else if instr.dest != "" {
            all_constant := true
            for arg in instr.args {
                if !slc.contains(outputs[:], arg) {
                    all_constant = false
                }
            }
            if all_constant {
                if !slc.contains(outputs[:], instr.dest) {
                    append(outputs, instr.dest)
                    changed = true
                }
            } else {
                idx, found := slc.linear_search(outputs[:], instr.dest)
                if found {
                    unordered_remove(outputs, idx)
                    changed = true
                }
            }
        }
    }
    return changed
}
