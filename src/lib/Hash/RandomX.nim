#Errors lib.
import ../Errors

#Hash master type.
import HashCommon

#RandomX library.
import mc_randomx

type
    #Flags + VM + Cache.
    RandomX* = ref object
        flags: RandomXFlags
        cacheKey*: string
        cache: RandomXCache
        vm: RandomXVM

    #Hash type.
    RandomXHash* = HashCommon.Hash[256]

proc newRandomX*(): RandomX {.forceCheck: [].} =
    result = RandomX(
        flags: getFlags(),
        cacheKey: "Initial RandomX Key." #Used by Meros's tests.
    )
    result.cache = allocCache(result.flags)
    result.cache.init(result.cacheKey)
    result.vm = createVM(result.flags, result.cache, nil)

#Set the key.
proc setCacheKey*(
    rx: RandomX,
    key: string
) {.forceCheck: [].} =
    rx.cacheKey = key
    rx.cache.init(key)
    rx.vm.setCache(rx.cache)

#Take in data; return a RandomXHash.
proc hash*(
    rx: RandomX,
    data: string
): RandomXHash {.forceCheck: [].} =
    try:
        var hashStr: string = rx.vm.hash(data)
        copyMem(addr result.data[0], addr hashStr[0], 32)
    except Exception:
        panic("RandomX raised an error.")

#String to RandomXHash.
proc toRandomXHash*(
    hash: string
): RandomXHash {.forceCheck: [
    ValueError
].} =
    try:
        result = hash.toHash(256)
    except ValueError as e:
        raise e
