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
    for instr in func.instrs {
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
    defer delete(block_map)
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

LVNTuple :: struct {
    op: string,
    nums: []int,
    value: Literal,
}

localLVN :: proc(func: ^Function) -> (changed: bool) {
    block_map := func2block_map(func^)
    defer delete(block_map)
    for _, block in block_map {
        vars    : map[Variable]int
        tuples  : map[int]LVNTuple
        origins : map[int]Variable
        defer delete(vars)
        defer delete(tuples)
        defer delete(origins)
        cur_num := 0
        for instr in block.instrs {
            // Construct our LVN tuple
            nums : [dynamic]int
            for arg, i in instr.args {
                append(&nums, vars[arg])
            }
            lvn : LVNTuple
            if instr.op == "id" {
                lvn = tuples[nums[0]]
            } else {
                lvn = LVNTuple{op = instr.op, nums = nums[:], value = instr.value}

                // We can sort communative operators as this won't have an
                // effect on the result
                if commutative_op(lvn.op) { slc.sort(lvn.nums[:]) }
            }
            // Check if we have a match
            idx, found := contains(tuples, lvn)
            if found {
                // Add copy propagation
                if instr.op == "id" {
                    vars[instr.dest] = idx
                    clear(&instr.args)
                    append(&instr.args, origins[idx])
                } else {
                    vars[instr.dest] = idx
                    instr.op = "id"
                    clear(&instr.args)
                    append(&instr.args, origins[idx])
                    // NOTE: might want to clear all other fields as well
                    changed = true
                }
            } else {
                if instr.dest != "" {
                    vars[instr.dest] = cur_num
                    origins[cur_num] = instr.dest
                }
                tuples[cur_num] = lvn
                cur_num += 1
                update_args(instr, vars, origins)
            }
            // Constant propogation
            // By checking if all sub-values are constants we can compute it
            // at compile time
            all_constant := len(instr.args) > 0
            vals : [dynamic]Literal
            defer delete(vals)
            for arg in instr.args {
                id := vars[arg]
                val := tuples[id].value
                if val != nil {
                    append(&vals, val)
                } else {
                    all_constant = false
                }
            }
            if all_constant && instr.dest != "" {
                instr.value = compute_constant(instr.op, vals[:])
                instr.op = "const"
                clear(&instr.args)
            }
        }
    }
    return changed
}

update_args :: proc(instr: ^Instruction, vars: map[Variable]int, origins : map[int]Variable) {
    for arg, i in instr.args {
        id := vars[arg]
        instr.args[i] = origins[id]
    }
}

contains :: proc(vars: map[int]LVNTuple, lvn: LVNTuple) -> (int, bool) {
    for idx, o_lvn in vars {
        if equiv(lvn, o_lvn) { return idx, true }
    }
    return 0, false
}

equiv :: proc(lvn: LVNTuple, o_lvn: LVNTuple) -> bool {
    same_args := true
    for i in 1..<min(len(lvn.nums), len(o_lvn.nums)) {
        if lvn.nums[i] != o_lvn.nums[i] { same_args = false }
    }
    return same_args && lvn.op == o_lvn.op && lvn.value == o_lvn.value
}

commutative_op :: proc(opCode : string) -> bool {
    return true
}

compute_constant :: proc(opCode : string, vals: []Literal) -> Literal {
    switch opCode {
        case "add": return vals[0].(i64) + vals[1].(i64)
        case "sub": return vals[0].(i64) - vals[1].(i64)
        case "mul": return vals[0].(i64) * vals[1].(i64)
        case "div": return vals[0].(i64) / vals[1].(i64)
        case "eq": return vals[0].(i64) == vals[1].(i64)
        case "lt": return vals[0].(i64) <  vals[1].(i64)
        case "gt": return vals[0].(i64) >  vals[1].(i64)
        case "le": return vals[0].(i64) <= vals[1].(i64)
        case "ge": return vals[0].(i64) >= vals[1].(i64)
        case "not": return !vals[0].(bool)
        case "and": return vals[0].(bool) && vals[1].(bool)
        case "or": return vals[0].(bool) || vals[1].(bool)
    }
    return nil
}
