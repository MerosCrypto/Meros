#Errors lib.
import ../Errors

#Hash master type.
import HashCommon

#Argon library.
import Argon2

#Define the Hash Type.
type ArgonHash* = HashCommon.Hash[384]

#Take in data and a salt; return a ArgonHash.
func Argon*(
    data: string,
    salt: string,
    reduced: bool = false
): ArgonHash {.raises: [ArgonError].} =
    #The iteration quantity and memory usage values are for testing only.
    #They are not final and will be changed.
    var
        #Reduced paramters:
        iterations: uint32 = 1
        memory: uint32 = 8 #8 KB of memory.
    if not reduced:
        #Regular paramters.
        memory = 131072 #128 MB of memory.

    try:
        result.data = Argon2d(
            data,
            salt,
            iterations,
            memory,
            1
        ).data
    except:
        raise newException(ArgonError, "Argon2d raised an error.")

#String to ArgonHash.
func toArgonHash*(hash: string): ArgonHash {.raises: [ValueError].} =
    hash.toHash(384)
