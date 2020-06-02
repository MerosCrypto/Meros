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

#StInt lib.
import StInt as StIntFile

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

#Check if a hash overflows when multiplied by a factor.
proc overflows*(
  hash: HashCommon.Hash[256],
  factor: uint32 or uint64
): bool {.raises: [].} =
  var original: StUInt[512]
  original.initFromBytesBE(hash.data)

  var product: array[64, byte] = (original * stuint(factor, 512)).toByteArrayBE()
  for b in 0 ..< 32:
    if product[b] != 0:
      return true

#These are stupid.
#These aren't debugging code.
#These aren't old code.
#These are statements needed for Meros to compile.
#Without these lines, the above function refuses to compile, complaining about an error in StInt.
#Don't touch it.
#-- Kayaba
discard HashCommon.Hash[256]().overflows(uint32(0))
discard HashCommon.Hash[256]().overflows(uint64(0))
