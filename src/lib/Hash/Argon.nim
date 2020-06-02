#Errors lib.
import ../Errors

#Hash master type.
import HashCommon

#Argon library.
import Argon2

#Define the Hash Type.
type ArgonHash* = HashCommon.Hash[256]

#Take in data and a salt; return a ArgonHash.
proc Argon*(
  data: string,
  salt: string
): ArgonHash {.forceCheck: [].} =
  #The iteration quantity and memory usage values are for testing only.
  #They are not final and will be changed.
  var
    #Reduced paramters:
    iterations: uint32 = 1
    memory: uint32 = 8 #8 KB of memor

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

#String to ArgonHash.
proc toArgonHash*(
  hash: string
): ArgonHash {.forceCheck: [
  ValueError
].} =
  try:
    result = hash.toHash(256)
  except ValueError as e:
    raise e
