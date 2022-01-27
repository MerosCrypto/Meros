import ForceCheck

import mc_randomx

import ../Log

import HashCommon

type
  #Flags + VM + Cache.
  RandomXObj = object
    flags: cint
    cacheKey*: string
    cache: RandomXCache
    vm: RandomXVM

  RandomX* = ref RandomXObj

#Destructor to ensure the pointers, referring to GB of data, are freed.
proc `=destroy`*(
  rx: var RandomXObj
) {.forceCheck: [].} =
  mc_randomx.dealloc(rx.cache)
  rx.cache = nil
  destroy rx.vm
  rx.vm = nil

proc newRandomX*(): RandomX {.forceCheck: [].} =
  result = RandomX(
    flags: getFlags(),
    cacheKey: "Initial RandomX Key." #Used by Meros's tests.
  )
  result.cache = allocCache(result.flags)
  result.cache.init(result.cacheKey)
  result.vm = createVM(result.flags, result.cache, nil)

#Update the cache key.
proc setCacheKey*(
  rx: RandomX,
  key: string
) {.forceCheck: [].} =
  rx.cacheKey = key
  rx.cache.init(key)
  rx.vm.setCache(rx.cache)

proc hash*(
  rx: RandomX,
  data: string
): Hash[256] {.forceCheck: [].} =
  try:
    var hashStr: string = rx.vm.hash(data)
    copyMem(addr result.data[0], addr hashStr[0], 32)
  except Exception:
    panic("RandomX raised an error.")
