package brilcore

import json "core:encoding/json"
import os "core:os"
import fmt "core:fmt"

main :: proc() {
    args := os.args
    defer delete(args)
    // TODO: Handle faulty options
    if len(args) != 1 {
        fmt.eprintln("usage: ./bril-odin < src.json")
        return
    }

    buf : [32786]u8
    n_bytes, read_err := os.read(os.stdin, buf[:])
    if read_err != 0 {
        fmt.eprintln("error reading input", n_bytes, read_err)
        return
    }

    src_json, parse_err := json.parse(buf[:n_bytes])
    defer json.destroy_value(src_json)
    if parse_err != json.Error.None {
        fmt.eprintln("error parsing json object")
        return
    }
    prg := json2prg(src_json.(json.Object))
    defer destroy_program(&prg)

    dest_json := prg2json(prg)

    options := json.Marshal_Options{pretty = true, use_spaces = true, spaces = 2}
    out, marshal_err := json.marshal(dest_json, options)
    if marshal_err != nil {
        fmt.eprintln("error marshalling json object")
        return
    }
    bytes_written, write_err := os.write(os.stdout, out[:])
    if write_err != 0 {
        fmt.eprintln("error reading input", bytes_written, write_err)
        return
    }
}
