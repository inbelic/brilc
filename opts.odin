package bril

import slc "core:slice"

// collection of various optimization strategies

// Global optimizations
simpleGlobalDCE :: proc(func: ^Function) -> (changed: bool) {
    used : [dynamic]Variable
    defer delete(used)

    for instr in func.instrs {
        for arg in instr.args {
            append(&used, arg)
        }
    }
    for _, i in func.instrs {
        instr := &func.instrs[i]
        if !instr.trim && instr.dest != "" && !slc.contains(used[:], instr.dest) {
            changed = true
            instr.trim = true
        }
    }
    return changed
}

// Local optimizations
simpleLocalDCE :: proc(func: ^Function) -> (changed: bool) {
    block_map := func2block_map(func^)
    for _, block in block_map {
        last_def : map[Variable]^Instruction
        defer delete(last_def)
        for instr in block.instrs {
            for arg in instr.args {
                delete_key(&last_def, arg)
            }
            if last_def[instr.dest] != nil {
                last_def[instr.dest].trim = true
                changed = true
            }
            last_def[instr.dest] = instr
        }
    }
    return changed
}
