import ../../lib/[Errors, Util, Hash]
import ../../Wallet/Wallet

import objects/DataObj
export DataObj

import ../../Network/Serialize/SerializeCommon
import ../../Network/Serialize/Transactions/SerializeData

proc newData*(
  input: Hash[256],
  data: string
): Data {.forceCheck: [
  ValueError
].} =
  #Verify the data length.
  if data.len == 0 or 256 < data.len:
    raise newLoggedException(ValueError, "Data is too small or too large.")

  result = newDataObj(input, data)
  result.hash = Blake256(result.serializeHash())

proc sign*(
  wallet: HDWallet,
  data: Data
) {.inline, forceCheck: [].} =
  data.signature = wallet.sign(data.hash.serialize())

proc mine*(
  data: Data,
  baseDifficulty: uint32
) {.forceCheck: [].} =
  var
    difficulty: uint32 = data.getDifficultyFactor() * baseDifficulty
    proof: uint32 = 0
    hash: Hash[256] = Argon(data.hash.serialize(), proof.toBinary(SALT_LEN))
  while hash.overflows(difficulty):
    inc(proof)
    hash = Argon(data.hash.serialize(), proof.toBinary(SALT_LEN))

  data.proof = proof
  data.argon = hash
