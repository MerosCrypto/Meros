#Errors lib.
import ../Errors

#Hash master type.
import HashCommon

#RandomX library.
import mc_randomx

#Define the Hash Type.
type RandomXHash* = HashCommon.Hash[256]

#Cache/VM.
var
    initialKey: string = "Initial RandomX Key." #Used by Meros's tests.
    flags: RandomXFlags = getFlags()
    cache: RandomXCache = allocCache(flags)
    vm: RandomXVM

cache.init(initialKey)
vm = createVM(flags, cache, nil)

#Set the key.
proc setRandomXKey*(
    key: string
) {.forceCheck: [].} =
    cache.init(key)
    vm.setCache(cache)

#Take in data; return a RandomXHash.
proc RandomX*(
    data: string
): RandomXHash {.forceCheck: [].} =
    try:
        var hashStr: string = vm.hash(data)
        copyMem(addr result.data[0], addr hashStr[0], 32)
    except Exception:
        doAssert(false, "RandomX raised an error.")

#String to RandomXHash.
func toRandomXHash*(
    hash: string
): RandomXHash {.forceCheck: [
    ValueError
].} =
    try:
        result = hash.toHash(256)
    except ValueError as e:
        raise e
