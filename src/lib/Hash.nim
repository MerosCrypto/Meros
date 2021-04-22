import hashes

import stint

import Hash/[HashCommon, Blake2, SHA2, Argon, RandomX]
export HashCommon, Blake2, SHA2, Argon, RandomX

template Blake64*(
  input: string
): uint64 =
  Blake2_64(input)

template Blake256*(
  input: string
): HashCommon.Hash[256] =
  Blake2_256(input)

template Blake512*(
  input: string
): HashCommon.Hash[512] =
  Blake2_512(input)

proc hash*[L](
  hash: HashCommon.Hash[L]
): hashes.Hash {.raises: [].} =
  for b in hash.data:
    result = result !& int(b)
  result = !$ result

#Check if a hash overflows when multiplied by a factor.
#Used for the difficulty code.
proc overflows*(
  hash: HashCommon.Hash[256],
  factor: uint32 or uint64
): bool {.raises: [].} =
  var
    hashCopy: array[64, byte]
    original: StUInt[512]
  for b in 0 ..< 32:
    hashCopy[b] = hash.data[b]
  original = StUInt[512].fromBytesLE(hashCopy)

  var product: array[64, byte] = (original * stuint(factor, 512)).toBytesLE()
  for b in 32 ..< 64:
    if product[b] != 0:
      return true

#[
These following lines are stupid.
They're not meant for debugging. They're not old leftovers.
These are statements needed for Meros to compile.
Without these lines, the above function refuses to compile, complaining about an error in StInt.
Don't touch these.
-- Kayaba
]#
discard HashCommon.Hash[256]().overflows(uint32(0))
discard HashCommon.Hash[256]().overflows(uint64(0))
