import nimcrypto

import strutils

var ctx512: sha512
proc SHA512*(hex: string): string =
    ctx512.init()

    var ints: string = ""
    for i in countup(0, hex.len-1, 2):
        ints = ints & ((char) parseHexInt(hex[i .. i + 1]))
    result = $sha512.digest(cast[ptr uint8]((cstring) ints), (uint) ints.len)

    ctx512.clear()


func `^`*(hash: proc(hex: string): string, times: int): proc(x: string): string =
    if times <= 0:
        result = proc(x: string): string =
            result = ""
        return

    return proc(hex: string): string =
        result = hash(hex)

        for i in 1 ..< times:
            result = hash(result)
