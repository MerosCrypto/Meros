#Hash Master Type/helper functions.
import Hash/HashCommon
export HashCommon

#SHA3 lib (used by Ember).
import Hash/SHA3
export SHA3

#Argon lib (used by Ember).
import Hash/Argon
export Argon

#SHA2 lib (for compatibility with old systems).
import Hash/SHA2
export SHA2

#RipeMD lib (for compatibility with BTC).
import Hash/RipeMD
export RipeMD

#Keccak lib (for compatibility with Ethereum).
import Hash/Keccak
export Keccak

#Define SHA3 as the default SHA hash family.
type
    SHA256Hash* = SHA3_256Hash
    SHA512Hash* = SHA3_512Hash
var
    SHA256*: proc (input: string): SHA256Hash {.raises: [].} = SHA3_256
    SHA512*: proc (input: string): SHA512Hash {.raises: [].} = SHA3_512
    toSHA256Hash*: proc (input: string): SHA256Hash {.raises: [ValueError].} = toSHA3_256Hash
    toSHA512Hash*: proc (input: string): SHA512Hash {.raises: [ValueError].} = toSHA3_512Hash
