import ../lib/objects/ErrorObjs

from ../lib/Util import randomFill

import BLS
export BLS

type MinerWallet* = ref object
  initiated*: bool
  privateKey*: BLSPrivateKey
  publicKey*: BLSPublicKey
  nick*: uint16

proc newMinerWallet*(
  privKey: string
): MinerWallet {.forceCheck: [
  BLSError
].} =
  try:
    result = MinerWallet(
      initiated: false,
      privateKey: newBLSPrivateKey(privKey)
    )
    result.publicKey = result.privateKey.toPublicKey()
  except BLSError as e:
    raise e

proc newMinerWallet*(): MinerWallet {.forceCheck: [
  BLSError
].} =
  #Create a Private Key.
  var privKey: string = newString(SCALAR_LEN)
  randomFill(privKey)

  try:
    result = newMinerWallet(privKey)
  except BLSError as e:
    raise e

proc sign*(
  miner: MinerWallet,
  msg: string
): BLSSignature {.inline, forceCheck: [].} =
  miner.privateKey.sign(msg)
