#Errors objects.
import ../lib/objects/ErrorObjs

#Util lib.
from ../lib/Util import randomFill

#BLS lib.
import BLS
export BLS

#Miner object.
type MinerWallet* = object
  #Initiated.
  initiated*: bool
  #Private Key.
  privateKey*: BLSPrivateKey
  #Public Key.
  publicKey*: BLSPublicKey
  #Nickname.
  nick*: uint16

#Constructors.
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
  RandomError,
  BLSError
].} =
  #Create a Private Key.
  var privKey: string = newString(G1_LEN)
  #Use nimcrypto to fill the Private Key with random bytes.
  try:
    randomFill(privKey)
  except RandomError:
    raise newException(RandomError, "Couldn't randomly fill the BLS Private Key.")

  try:
    result = newMinerWallet(privKey)
  except BLSError as e:
    raise e

#Sign a message via a MinerWallet.
proc sign*(
  miner: MinerWallet,
  msg: string
): BLSSignature {.inline, forceCheck: [].} =
  miner.privateKey.sign(msg)
