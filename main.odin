package brilcore

import json "core:encoding/json"
import os "core:os"
import fmt "core:fmt"

main :: proc() {
    args := os.args
    defer delete(args)
    if len(args) != 2 {
        fmt.eprintln("usage: ./brilc src")
        return
    }

    src, success := os.read_entire_file_from_filename(args[1])
    defer delete(src)
    if !success {
        fmt.eprintln("error reading input src file")
        return
    }

    src_json, err := json.parse(src)
    defer json.destroy_value(src_json)
    if err != json.Error.None {
        fmt.eprintln("error parsing json object")
        return
    }
    prg := json2adt(src_json.(json.Object))
    defer destroy_program(&prg)

    fmt.println(prg)
}
