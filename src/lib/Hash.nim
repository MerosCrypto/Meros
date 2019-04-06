#Hash Master Type/helper functions.
import Hash/HashCommon
export HashCommon

#Blake lib (used by Meros).
import Hash/Blake2
export Blake2

#Argon lib (used by Meros).
import Hash/Argon
export Argon

#SHA2 lib (for compatibility with old systems such as BTC).
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

#Define Blake_2 as Blake.
type
    Blake384Hash* = Blake2_384Hash
var
    Blake384*: proc (input: string): Blake384Hash {.raises: [].} = Blake2_384
    toBlake384Hash*: proc (input: string): Blake384Hash {.raises: [ValueError].} = toBlake2_384Hash
