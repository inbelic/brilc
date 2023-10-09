package brilcore

// Exports json2adt which will take a well-formed bril program JSON object and
// convert it to our ADTs defined in adt.odin

import json "core:encoding/json"

json2adt :: proc(prg: json.Object) -> Program {
    return json2prg(prg)
}

@(private="file")
json2type :: proc(type_val: json.Value) -> (type: Type) {
    #partial switch _ in type_val {
        case json.String: {
            type.name = type_val.(json.String)
        }
        case json.Object: {
            // TODO: implement extension types
        }
    }
    return type
}

@(private="file")
json2lit :: proc(lit_val: json.Value) -> (lit: Literal) {
    #partial switch _ in lit_val {
        case json.Integer: lit = lit_val.(json.Integer)
        case json.Boolean: lit = lit_val.(json.Boolean)
    }
    return lit
}

@(private="file")
json2arg :: proc(arg_val: json.Value) -> (arg: Arg) {
    arg_obj := arg_val.(json.Object)
    arg.name = arg_obj["name"].(json.String)
    arg.type = json2type(arg_obj["type"]) // Well-formed will not be nil
    return arg
}

@(private="file")
json2instr :: proc(instr_val: json.Object) -> (instr: Instruction) {
    op := instr_val["op"]
    if op == nil {
        instr.op = ""
    } else {
        instr.op = op.(json.String)
    }
    dest := instr_val["dest"]
    if dest == nil {
        instr.dest = ""
    } else {
        instr.dest = dest.(json.String)
    }
    type := instr_val["type"]
    if type == nil {
        instr.type = nil
    } else {
        instr.type = new(Type)
        instr.type^ = json2type(type)
    }
    args := instr_val["args"]
    if args != nil {
        for arg_val in args.(json.Array) {
            append(&instr.args, arg_val.(json.String))
        }
    }
    funcs := instr_val["funcs"]
    if funcs != nil {
        for func_val in funcs.(json.Array) {
            append(&instr.funcs, func_val.(json.String))
        }
    }
    labels := instr_val["labels"]
    if labels != nil {
        for label_val in labels.(json.Array) {
            append(&instr.labels, label_val.(json.String))
        }
    }
    label := instr_val["label"]
    if label == nil {
        instr.label = ""
    } else {
        instr.label = label.(json.String)
    }
    return instr
}

@(private="file")
json2func :: proc(func_val: json.Value) -> (func: Function) {
    func_obj := func_val.(json.Object)
    func.name = func_obj["name"].(json.String)  // Well-formedness will not be nil
    args := func_obj["args"]
    if args != nil {
        for arg_val in args.(json.Array) {
            append(&func.args, json2arg(arg_val))
        }
    }
    type := func_obj["type"]
    if type != nil {
        func.type = new(Type)
        func.type^ = json2type(type)
    }
    instrs := func_obj["instrs"].(json.Array)
    for instr_val in instrs { // Well-formedness will not be nil
        append(&func.instrs, json2instr(instr_val.(json.Object)))
    }
    return func
}

@(private="file")
json2prg :: proc(prg_src: json.Object) -> (prg: Program) {
    funcs := prg_src["functions"].(json.Array)
    for func_val in funcs {
        append(&prg, json2func(func_val))
    }
    return prg
}
