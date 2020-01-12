#Hash Master Type/helper functions.
import Hash/HashCommon
export HashCommon

#Blake lib (used by Meros).
import Hash/Blake2
export Blake2

#RandomX lib (used by Meros).
import Hash/RandomX
export RandomX

#Argon lib (used by Meros).
import Hash/Argon
export Argon

#SHA2 lib (for compatibility with older systems such as BTC).
import Hash/SHA2
export SHA2

#RipeMD lib (for compatibility with BTC).
import Hash/RipeMD
export RipeMD

#Keccak lib (for compatibility with Ethereum).
import Hash/Keccak
export Keccak

#SHA3 lib (formerly used by Meros).
import Hash/SHA3
export SHA3

#Hashes standard lib.
import hashes

#Define Blake_2 as Blake.
type Blake256Hash* = Blake2_256Hash

template Blake64*(
    input: string
): uint64 = Blake2_64(input)

template Blake256*(
    input: string
): Blake256Hash = Blake2_256(input)

template toBlake256Hash*(
    input: string
): Blake256Hash = toBlake2_256Hash(input)

proc hash*[L](
    hash: HashCommon.Hash[L]
): hashes.Hash {.raises: [].} =
    for b in hash.data:
        result = result !& int(b)
    result = !$ result
