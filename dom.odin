package bril

import slc "core:slice"

// implements a way to compute the dominance frontier of a function

LabelMap :: map[Label][dynamic]Label

// this computes the map from a block to the dominators of a given block
func2dom_map :: proc(func: ^Function) -> (dom_map: LabelMap) {
    cfg := func2block_map(func^)
    defer delete(cfg)
    preds := predeccessor_map(cfg)
    defer delete(preds)
    labels, _ := slc.map_keys(preds)
    for name, _ in cfg {
        dom_map[name] = make([dynamic]Label, 0)
        for label in labels {
            append(&dom_map[name], label)
        }
    }
    changed := true
    for changed {
        changed = false
        // TODO: iterate in reverse post-order
        for name, _ in cfg {
            intersection : [dynamic]Label
            defer delete(intersection)
            if !slc.is_empty(preds[name][:]) {
                for label in labels[:] {
                    append(&intersection, label)
                }
            }
            for p in preds[name] {
                intersect(&intersection, dom_map[p][:])
            }
            if !slc.contains(intersection[:], name) {
                append(&intersection, name)
            }
            local_changed := !equiv_sets(dom_map[name][:], intersection[:])
            if local_changed {
                changed = true
                clear(&dom_map[name])
                for v in intersection[:] {
                    append(&dom_map[name], v)
                }
            }
        }
    }
    return dom_map
}

dom_map2dom_tree :: proc(dom_map: LabelMap) -> (dom_tree: LabelMap) {
    for label, _ in dom_map {
        dom_tree[label] = make([dynamic]Label, 0)
    }

    for label, _ in dom_map {
        doms := dom_map[label][:]
        for d in doms {
            if d != label { // all nodes that strictly dominate label
                idom := true
                for dd in doms {
                    if dd != d && dd != label && slc.contains(dom_map[dd][:], d) {
                        idom = false
                        continue
                    }
                }
                if idom {
                    append(&dom_tree[d], label)
                    continue
                }
            }
        }
    }
    return dom_tree
}

construct_dom_front :: proc(dom_map, preds: LabelMap) -> (dom_front: LabelMap) {
    for label, _ in dom_map {
        dom_front[label] = make([dynamic]Label, 0)
    }

    for label, ps in preds {
        doms := dom_map[label] // all the dominators of label
        for p in ps {
            for p_dom in dom_map[p][:] { // p_dom(A) is a dominator of a pred
                if !slc.contains(doms[:], p_dom) || p_dom == label {
                    // p_dom(A) is not a strict dom of label(B) and so label is
                    // in the frontier of p_dom
                    if !slc.contains(dom_front[p_dom][:], label) {
                        append(&dom_front[p_dom], label)
                    }
                }
            }
        }
    }
    return dom_front
}

// Helpers
intersect :: proc(xs: ^[dynamic]$T, ys: []T) {
    zs : [dynamic]T
    defer delete(zs)
    for x in xs[:] {
        if slc.contains(ys, x) {
            append(&zs, x)
        }
    }
    clear(xs)
    for z in zs {
        append(xs, z)
    }
}

equiv_sets :: proc(xs: []$T, ys: []T) -> bool {
    for x in xs {
        if !slc.contains(ys, x) {
            return false
        }
    }
    for y in ys {
        if !slc.contains(xs, y) {
            return false
        }
    }
    return true
}
