#Errors lib.
import ../Errors

#Util lib.
import ../Util

#Hash type.
import objects/HashObj
export HashObj

#Empty uint8 'array'.
const EMPTY_HASH*: ptr uint8 = nil

#toHash functions.
proc toHash*(
    hash: string,
    bits: static[int]
): Hash[bits] {.forceCheck: [
    ValueError
].} =
    if hash.len == bits div 8:
        for i in 0 ..< hash.len:
            result.data[i] = uint8(hash[i])
    elif hash.len div 2 == bits div 8:
        for i in countup(0, hash.len - 1, 2):
            result.data[i div 2] = uint8(parseHexInt(hash[i .. i + 1]))
    else:
        raise newLoggedException(ValueError, "toHash not handed the right amount of data.")

#toHash dedicated for Stint.
proc toHash*(
    hash: openArray[byte],
    bits: static[int]
): Hash[bits] {.forceCheck: [
    ValueError
].} =
    if hash.len == bits div 8:
        for i in 0 ..< hash.len:
            result.data[i] = uint8(hash[i])
    else:
        raise newLoggedException(ValueError, "toHash not handed the right amount of data.")

#To binary string.
func toString*(
    hash: Hash
): string {.forceCheck: [].} =
    for b in hash.data:
        result &= char(b)

#To hex string.
func `$`*(
    hash: Hash
): string {.forceCheck: [].} =
    for b in hash.data:
        result &= b.toHex()

#Check if a hash is empty.
proc empty*(
    hash: Hash
): bool {.forceCheck: [].} =
    for b in hash.data:
        if b != 0:
            return false
    result = true

#Compare hash values.
func `<`*[bits: static[int]](
    lhs: Hash[bits],
    rhs: Hash[bits]
): bool =
    var bytes: int = bits div 8
    for i in 0 ..< bytes:
        if lhs.data[i] == rhs.data[i]:
            continue
        elif lhs.data[i] < rhs.data[i]:
            return true
        else:
            return false
    return false

func `<=`*[bits: static[int]](
    lhs: Hash[bits],
    rhs: Hash[bits]
): bool =
    var bytes: int = bits div 8
    for i in 0 ..< bytes:
        if lhs.data[i] == rhs.data[i]:
            continue
        elif lhs.data[i] < rhs.data[i]:
            return true
        else:
            return false
    return true

func `>`*[bits: static[int]](
    lhs: Hash[bits],
    rhs: Hash[bits]
): bool =
    var bytes: int = bits div 8
    for i in 0 ..< bytes:
        if lhs.data[i] == rhs.data[i]:
            continue
        elif lhs.data[i] > rhs.data[i]:
            return true
        else:
            return false
    return false

func `>=`*[bits: static[int]](
    lhs: Hash[bits],
    rhs: Hash[bits]
): bool =
    var bytes: int = bits div 8
    for i in 0 ..< bytes:
        if lhs.data[i] == rhs.data[i]:
            continue
        elif lhs.data[i] > rhs.data[i]:
            return true
        else:
            return false
    return true

func `==`*[bits: static[int]](
    lhs: Hash[bits],
    rhs: Hash[bits]
): bool =
    var bytes: int = bits div 8
    for i in 0 ..< bytes:
        if lhs.data[i] == rhs.data[i]:
            continue
        else:
            return false
    return true
