package bril

// Define our ADT's
Program :: distinct [dynamic]Function

Type :: struct {
    name: string,
    type: ^Type,
}

Function :: struct {
    name: string,
    args: [dynamic]Arg,
    type: ^Type,
    instrs: [dynamic]^Instruction,
}

Arg :: struct {
    name: string,
    type: Type,
}

Label       :: string
Variable    :: string
FuncRef     :: string

Instruction :: struct {
    op: string,
    dest: string,
    type: ^Type,
    args: [dynamic]Variable,
    funcs: [dynamic]FuncRef,
    labels: [dynamic]Label,
    label: string,
    value: Literal,
    trim: bool,
}

Literal :: union {
    i64,
    bool,
}

destroy_program :: proc(prg: ^Program) {
    for func in prg {
        destroy_func(func)
    }
    delete(prg^)
}

destroy_instr :: proc(instr: Instruction) {
    if (instr.type != nil) {
        free(instr.type)
    }
    delete(instr.args)
    delete(instr.funcs)
    delete(instr.labels)
}

destroy_type :: proc(type: ^Type) {
    if type.type != nil {
        destroy_type(type.type)
    }
    free(type)
}

destroy_func :: proc(func: Function) {
    delete(func.args)
    for instr in func.instrs {
        destroy_instr(instr^)
        free(instr)
    }
    delete(func.instrs)
    if func.type != nil {
        destroy_type(func.type)
    }
}

trim :: proc(func: ^Function) {
    trimmed : [dynamic]^Instruction
    for instr in func.instrs[:] {
        if !instr.trim {
            append(&trimmed, instr)
        }
    }
    func.instrs = trimmed
}
