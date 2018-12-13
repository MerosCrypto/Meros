#Errors lib.
import ../Errors

#Hash master type.
import HashCommon

#Argon library.
import Argon2

#Define the Hash Type.
type ArgonHash* = HashCommon.Hash[512]

#Take in data and a salt; return a ArgonHash.
func Argon*(
    data: string,
    salt: string,
    reduced: bool = false
): ArgonHash {.raises: [ArgonError].} =
    #The iteration quantity and memory usage values are for testing only.
    #They are not final and will be changed.
    var
        iterations: uint32
        memory: uint32
    if not reduced:
        #Use 128 MB of RAM.
        iterations = 1
        memory = 131072
    else:
        #Use 8KB of RAM.
        memory = 8

    try:
        result.data = Argon2d(
            data,
            salt,
            1,
            memory,
            1
        ).data
    except:
        raise newException(ArgonError, "Argon2d raised an error.")

#String to ArgonHash.
func toArgonHash*(hash: string): ArgonHash {.raises: [ValueError].} =
    hash.toHash(512)
