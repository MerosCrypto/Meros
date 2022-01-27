import ../lib/objects/ErrorObjs

when defined(merosTests):
  from ../lib/Util import randomFill
import ../lib/Hash

import BLS
export BLS

type MinerWallet* = ref object
  initiated*: bool
  privateKey*: BLSPrivateKey
  publicKey*: BLSPublicKey
  nick*: uint16

proc newMinerWallet*(
  privKeyArg: string
): MinerWallet {.forceCheck: [
  BLSError
].} =
  var privKey: string
  #Raw seed from the Mnemonic requiring wide reduction.
  if privKeyArg.len == 64:
    #Apply a DST to differentiate it from the MR wallet (Ristretto).
    privKey = Blake512("BLS" & privKeyArg).serialize()
  #Established scalar.
  else:
    privKey = privKeyArg

  try:
    result = MinerWallet(
      initiated: false,
      privateKey: newBLSPrivateKey(privKey)
    )
    result.publicKey = result.privateKey.toPublicKey()
  except BLSError as e:
    raise e

when defined(merosTests):
  proc newMinerWallet*(): MinerWallet {.forceCheck: [
    BLSError
  ].} =
    #Create a Private Key.
    var privKey: string = newString(SCALAR_LEN * 2)
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
