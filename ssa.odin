package bril

import slc "core:slice"
import fmt "core:fmt"

// converts a bril program into the equivalent SSA form with phi operations
// and from an SSA form back to a bril program

insert_phi :: proc(func: ^Function, block_map: ^BlockMap, dom_front: LabelMap) {
    vars : map[Variable][dynamic]Label
    defer delete(vars)

    for label, block in block_map {
        for instr in block.instrs {
            if instr.dest != "" {
                if vars[instr.dest] == nil {
                    vars[instr.dest] = make([dynamic]Label, 0)
                }
                if !slc.contains(vars[instr.dest][:], label) {
                    append(&vars[instr.dest], label)
                }
            }
        }
    }

    for v, defs in vars {
        for !slc.is_empty(vars[v][:]) {
            clear(&vars[v])
            for d in defs {
                for df in dom_front[d] {
                    block := &block_map[df]
                    instr := block.instrs[0]
                    if instr.op != "phi" || instr.dest != v {
                        phi := new(Instruction)
                        phi.op = "phi"
                        phi.dest = v
                        phi.args = make([dynamic]Variable, 0)
                        // store a temporary value to hold the base arg value
                        append(&phi.args, v)
                        phi.labels = make([dynamic]Label, 0)
                        idx, _ := slc.linear_search(func.instrs[:], instr)
                        inject_at(&func.instrs, idx, phi)
                        inject_at(&block.instrs, 0, phi)
                        append(&vars[v], d)
                    }
                }
            }
        }
    }
}

StackMap :: map[Variable][dynamic]int
DefnMap :: map[Variable]int

rename :: proc(block_map: ^BlockMap, dom_tree: LabelMap) {
    stack : StackMap
    defer destroy_stacks(stack)
    defns : DefnMap
    defer delete(defns)

    rename_work(block_map, dom_tree, stack, &defns, ".ENTRY")

    // remove use of temp arg to contain var name
    for _, block in block_map {
        for instr in block.instrs {
            if instr.op == "phi" {
                pop_front(&instr.args)
            }
        }
    }
}

rename_work :: proc(block_map: ^BlockMap, dom_tree: LabelMap, prev_stack: StackMap, defns : ^DefnMap, label: Label) {
    block := block_map[label]
    stack := deep_clone(prev_stack)
    defer destroy_stacks(stack)
    for instr in block.instrs {
        // Refer to the last used variable
        if instr.op != "phi" {
            for arg, i in instr.args {
                vals, exists := stack[arg]
                if exists {
                    end_idx := len(vals)
                    x := vals[end_idx - 1]
                    instr.args[i] = fmt.tprintf("%s.%d", arg, x)
                }
            }
        }
        // Increment each new assignment of a variable
        if instr.dest != "" {
            x, exists := defns[instr.dest]
            if !exists {
                x = -1
            }
            _, exists = stack[instr.dest]
            if !exists {
                stack[instr.dest] = make([dynamic]int, 0)
            }
            append(&stack[instr.dest], x + 1)
            defns[instr.dest] = x + 1
            instr.dest = fmt.tprintf("%s.%d", instr.dest, x + 1)
        }
    }
    // Iterate over our succs
    if block.true_next != "" {
        for instr in block_map[block.true_next].instrs {
            if instr.op == "phi" {
                v := instr.args[0]
                vals := stack[v]
                end_idx := len(vals)
                x := vals[end_idx - 1]
                append(&instr.args, fmt.tprintf("%s.%d", v, vals[end_idx - 1]))
                append(&instr.labels, label)
            }
        }
    }
    if block.false_next != "" {
        for instr in block_map[block.false_next].instrs {
            if instr.op == "phi" {
                v := instr.args[0]
                vals := stack[v]
                end_idx := len(vals)
                x := vals[end_idx - 1]
                append(&instr.args, fmt.tprintf("%s.%d", instr.dest, vals[0]))
                append(&instr.labels, label)
            }
        }
    }
    // Recurse to the immediately dominated children
    for nxt_label in dom_tree[label] {
        rename_work(block_map, dom_tree, stack, defns, nxt_label)
    }
}

destroy_stacks :: proc(stack: StackMap) {
    for _, vals in stack {
        delete(vals)
    }
    delete(stack)
}

deep_clone :: proc(src: StackMap) -> (dest: StackMap) {
    for k, vals in src {
        dest[k] = make([dynamic]int, 0)
        for v in vals {
            append(&dest[k], v)
        }
    }
    return dest
}

remove_phi :: proc(func: ^Function, block_map: ^BlockMap) {
    // iterate to generate the required id values
    for cur_label, cur_block in block_map {
        for instr in cur_block.instrs {
            if instr.op == "phi" {
                for label, i in instr.labels {
                    arg := instr.args[i]
                    block := block_map[label]
                    pred_instr := block.instrs[0]

                    id := new(Instruction)
                    id.op = "id"
                    id.dest = instr.dest
                    id.args = make([dynamic]Variable, 0)
                    append(&id.args, arg)

                    inject_at(&block.instrs, 0, id)

                    // We then need to place it before the first jmp, br to
                    // our current label
                    idx, _ := slc.linear_search(func.instrs[:], pred_instr)
                    offset_max := len(block.instrs)
                    offset := 1
                    for offset <= offset_max {
                        t_instr := func.instrs[idx + offset]
                        if slc.contains(t_instr.labels[:], cur_label) { break }
                        offset += 1
                    }
                    inject_at(&func.instrs, idx + offset, id)
                }
            }
        }
    }
    // iterate to remove the phi values
    for _, block in block_map {
        // reverse order so to not have index conflict
        #reverse for instr, i in block.instrs[:] {
            if instr.op == "phi" {
                ordered_remove(&block.instrs, i)
                idx, _ := slc.linear_search(func.instrs[:], instr)
                ordered_remove(&func.instrs, idx)
                free(instr)
            }
        }
    }
}
