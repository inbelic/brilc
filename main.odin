package bril

import json "core:encoding/json"
import os "core:os"
import fmt "core:fmt"

main :: proc() {
    args := os.args
    defer delete(args)
    if len(args) != 2 {
        fmt.eprintln("usage: ./bril-odin PASS < src.json")
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

    switch args[1] {
        case "--misc-print-form-blocks": {
            for func in prg {
                block_map := func2block_map(func)
                fmt.println("\n", block_map)
            }
            return
        }
        case "--misc-count-additions": {
            num_adds := 0
            for func in prg {
                for instr in func.instrs {
                    if instr.op == "add" {
                        num_adds += 1
                    }
                }
            }
            fmt.println("program has", num_adds, "additions")
            return
        }
        case "--opt-simpleDCE": {
            for _, i in prg {
                func := &prg[i]
                for simpleGlobalDCE(func) || simpleLocalDCE(func) {
                    trim(func)
                }
            }
        }
        case "--opt-localLVN": {
            for _, i in prg {
                func := &prg[i]
                for localLVN(func) {}
            }
        }
        case "--opt-complete": {
            for _, i in prg {
                func := &prg[i]
                for localLVN(func) || simpleGlobalDCE(func) || simpleLocalDCE(func) {
                    trim(func)
                }
            }
        }
        case "--dfa-defined": {
            for _, i in prg {
                func := &prg[i]
                worklist_forward(func, null_vec, union_merge, defined_transfer)
            }
            return
        }
        case "--dfa-livevars": {
            for _, i in prg {
                func := &prg[i]
                worklist_backward(func, null_vec, union_merge, livevar_transfer)
            }
            return
        }
        case "--dfa-cprop": {
            for _, i in prg {
                func := &prg[i]
                worklist_forward(func, null_vec, union_merge, cprop_transfer)
            }
            return
        }
        case "--dom-map": {
            for _, i in prg {
                func := &prg[i]
                dom_map := func2dom_map(func)
                fmt.eprintln(dom_map)
                defer delete(dom_map)
            }
            return
        }
        case "--dom-tree": {
            for _, i in prg {
                func := &prg[i]
                dom_map := func2dom_map(func)
                defer delete(dom_map)
                dom_tree := dom_map2dom_tree(dom_map)
                defer delete(dom_tree)
                fmt.eprintln(dom_tree)
            }
            return
        }
        case "--dom-front": {
            for _, i in prg {
                func := &prg[i]
                dom_map := func2dom_map(func)
                defer delete(dom_map)
                preds := predeccessor_map(func2block_map(func^))
                defer delete(preds)
                dom_front := construct_dom_front(dom_map, preds)
                defer delete(dom_front)
                fmt.eprintln(dom_front)
            }
            return
        }
        case:
    }
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
