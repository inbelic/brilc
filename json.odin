package bril

// Exports json2prg which will take a well-formed bril program JSON object and
// convert it to our ADTs defined in adt.odin. Then also provide the other
// way of prg2json

import json "core:encoding/json"

json2prg :: proc(prg_val: json.Object) -> (prg: Program) {
    funcs := prg_val["functions"].(json.Array)
    for func_val in funcs {
        append(&prg, json2func(func_val))
    }
    return prg
}


prg2json :: proc(prg: Program) -> (prg_obj: json.Object) {
    funcs : json.Array
    for func in prg {
        append(&funcs, func2json(func))
    }
    prg_obj["functions"] = funcs
    return prg_obj
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
json2instr :: proc(instr_val: json.Object) -> ^Instruction {
    instr := new(Instruction)
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
    value := instr_val["value"]
    if value == nil {
        instr.value = nil
    } else {
        #partial switch _ in value {
            case json.Integer: instr.value = value.(json.Integer)
            case json.Boolean: instr.value = value.(json.Boolean)
            case f64: instr.value = i64(value.(f64))
        }
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
type2json :: proc(type: Type) -> json.Value {
    if type.type != nil {
        type_obj : json.Object
        type_obj["name"] = type.name
        type_obj["type"] = type2json(type.type^)
        return type_obj
    }
    type_name : json.String
    type_name = type.name
    return type_name
}

@(private="file")
arg2json :: proc(arg: Arg) -> (arg_obj: json.Object) {
    arg_obj["name"] = arg.name
    arg_obj["type"] = type2json(arg.type)
    return arg_obj
}

@(private="file")
instr2json :: proc(instr: Instruction) -> (instr_obj: json.Object) {
    if instr.op != "" {
        instr_obj["op"] = instr.op
    }
    if instr.dest != "" {
        instr_obj["dest"] = instr.dest
    }
    if instr.type != nil {
        instr_obj["type"] = type2json(instr.type^)
    }
    args : json.Array
    for arg in instr.args {
        append(&args, arg)
    }
    if len(args) != 0 {
        instr_obj["args"] = args
    }
    funcs : json.Array
    for func in instr.funcs {
        append(&funcs, func)
    }
    if len(funcs) != 0 {
        instr_obj["funcs"] = funcs
    }
    labels : json.Array
    for label in instr.labels {
        append(&labels, label)
    }
    if len(labels) != 0 {
        instr_obj["labels"] = labels
    }
    if instr.label != "" {
        instr_obj["label"] = instr.label
    }
    if instr.value != nil {
        #partial switch _ in instr.value {
            case i64: instr_obj["value"] = instr.value.(i64)
            case bool: instr_obj["value"] = instr.value.(bool)
        }
    }
    return instr_obj
}

@(private="file")
func2json :: proc(func: Function) -> (func_obj: json.Object) {
    func_obj["name"] = json.String(func.name)
    args : json.Array
    for arg in func.args {
        append(&args, arg2json(arg))
    }
    if len(args) != 0 {
        func_obj["args"] = args
    }
    if func.type != nil {
        func_obj["type"] = type2json(func.type^)
    }
    instrs : json.Array
    for instr in func.instrs {
        append(&instrs, instr2json(instr^))
    }
    if len(instrs) != 0 {
        func_obj["instrs"] = instrs
    }
    return func_obj
}
