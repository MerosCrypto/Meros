import ForceCheck

import Argon2

import ../Log

import HashCommon

proc Argon*(
  data: string,
  salt: string
): HashCommon.Hash[256] {.forceCheck: [].} =
  #The iteration quantity and memory usage values are for testing only.
  #They are not final and will be changed.
  var
    iterations: uint32 = 1
    memory: uint32 = 8

  try:
    result.data = Argon2d(
      data,
      salt,
      iterations,
      memory,
      1
    ).data
  except Exception:
    panic("Argon2d raised an error.")
