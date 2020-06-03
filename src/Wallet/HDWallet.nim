import math
import StInt

import ../lib/[Errors, Util, Hash]

import Ed25519, Address
export Ed25519, Address

import ../Network/Serialize/SerializeCommon

const
  #BIP 44 Coin Type.
  COIN_TYPE {.intdefine.}: uint32 = 0
  #Ed25519's l value.
  l: StUInt[256] = "7237005577332262213973186563042994240857116359379907606001950938285454250989".parse(StUInt[256])

type HDWallet* = object
  chainCode*: Hash[256]
  privateKey*: EdPrivateKey
  publicKey*: EdPublicKey
  address*: string

func sign*(
  wallet: HDWallet,
  msg: string
): EdSignature {.inline, forceCheck: [].} =
  wallet.privateKey.sign(wallet.publicKey, msg)

func verify*(
  wallet: HDWallet,
  msg: string,
  sig: EdSignature
): bool {.inline, forceCheck: [].} =
  wallet.publicKey.verify(msg, sig)

proc newHDWallet*(
  secretArg: string
): HDWallet {.forceCheck: [
  ValueError
].} =
  #Parse the secret.
  var secret: string = secretArg
  if secret.len == 64:
    try:
      secret = secretArg.parseHexStr()
    except ValueError:
      raise newLoggedException(ValueError, "Hex-length secret with invalid Hex data passed to newHDWallet.")
  elif secret.len == 32:
    discard
  else:
    raise newLoggedException(ValueError, "Invalid length secret passed to newHDWallet.")

  #Keys.
  var
    privateKey: EdPrivateKey
    publicKey: EdPublicKey

  #Create the Private Key.
  privateKey.data = cast[array[64, cuchar]](SHA2_512(secret).data)
  if (byte(privateKey.data[31]) and 0b00100000) != 0:
    raise newLoggedException(ValueError, "Secret generated an invalid private key.")
  privateKey.data[0]  = cuchar(byte(privateKey.data[0])  and (not byte(0b00000111)))
  privateKey.data[31] = cuchar(byte(privateKey.data[31]) and (not byte(0b10000000)))
  privateKey.data[31] = cuchar(byte(privateKey.data[31]) or       0b01000000)

  #Create the Public Key.
  publicKey = privateKey.toPublicKey()

  result = HDWallet(
    #Set the Wallet fields.
    privateKey: privateKey,
    publicKey: publicKey,
    address: newAddress(AddressType.PublicKey, publicKey.serialize()),

    #Create the chain code.
    chainCode: SHA2_256('\1' & secret)
  )

#Derive a Child HD Wallet.
proc derive*(
  wallet: HDWallet,
  childArg: uint32
): HDWallet {.forceCheck: [
  ValueError
].} =
  var
    #Parent properties, serieslized in little endian.
    pChainCode: string = wallet.chainCode.serialize()
    pPrivateKey: string = wallet.privateKey.serialize()
    pPrivateKeyL: array[32, byte]
    pPrivateKeyR: array[32, byte]
    pPublicKey: string = wallet.publicKey.serialize()

    #Child index, in little endian.
    child: string = childArg.toBinary(INT_LEN).reverse()
    #Is this a Hardened derivation?
    hardened: bool = childArg >= (uint32(2) ^ 31)
  for i in 0 ..< 32:
    pPrivateKeyL[31 - i] = byte(pPrivateKey[i])
    pPrivateKeyR[31 - i] = byte(pPrivateKey[32 + i])

  #Calculate Z and the Chaincode.
  var
    Z: Hash[512]
    chainCodeExtended: Hash[512]
    chainCode: Hash[256]
  if hardened:
    Z = HMAC_SHA2_512(pChainCode, '\0' & pPrivateKey & child)
    chainCodeExtended = HMAC_SHA2_512(pChainCode, '\1' & pPrivateKey & child)
    copyMem(addr chainCode.data[0], addr chainCodeExtended.data[32], 32)
  else:
    Z = HMAC_SHA2_512(pChainCode, '\2' & pPublicKey & child)
    chainCodeExtended = HMAC_SHA2_512(pChainCode, '\3' & pPublicKey & child)
    copyMem(addr chainCode.data[0], addr chainCodeExtended.data[32], 32)

  var
    #Z left and right.
    zL: array[32, byte]
    zR: array[32, byte]
    #Key left and right.
    kL: StUInt[256]
    kR: StUInt[256]
  for i in 0 ..< 32:
    if i < 28:
      zL[31 - i] = Z.data[i]
    zR[31 - i] = Z.data[i + 32]

  #Calculate the Private Key.
  kL = (readUIntBE[256](zL) * 8) + readUIntBE[256](pPrivateKeyL)
  try:
    if kL mod l == 0:
      raise newLoggedException(ValueError, "Deriving this child key produced an unusable PrivateKey.")
  except DivByZeroError:
    panic("Performing a modulus of Ed25519's l raised a DivByZeroError.")

  kR = readUIntBE[256](zR) + readUIntBE[256](pPrivateKeyR)

  #Set the PrivateKey.
  var
    tempL: array[32, byte] = kL.toByteArrayBE()
    tempR: array[32, byte] = kR.toByteArrayBE()
    privateKey: EdPrivateKey
  for i in 0 ..< 32:
    privateKey.data[31 - i] = cuchar(tempL[i])
    privateKey.data[63 - i] = cuchar(tempR[i])

  #Create the Public Key.
  var publicKey: EdPublicKey = privateKey.toPublicKey()

  result = HDWallet(
    #Set the Wallet fields.
    privateKey: privateKey,
    publicKey: publicKey,
    address: newAddress(AddressType.PublicKey, publicKey.serialize()),

    #Set the chain code.
    chainCode: chainCode
  )

#Derive a full path.
proc derive*(
  wallet: HDWallet,
  path: seq[uint32]
): HDWallet {.forceCheck: [
  ValueError
].} =
  if path.len == 0:
    return wallet
  if path.len >= 2^20:
    raise newLoggedException(ValueError, "Derivation path depth is too big.")

  try:
    result = wallet.derive(path[0])
    for i in path[1 ..< path.len]:
        result = result.derive(i)
  except ValueError as e:
    raise e

#Get a specific BIP 44 child.
proc `[]`*(
  wallet: HDWallet,
  account: uint32
): HDWallet {.forceCheck: [
  ValueError
].} =
  try:
    result = wallet.derive(@[
      uint32(44) + (uint32(2) ^ 31),
      COIN_TYPE + (uint32(2) ^ 31),
      account + (uint32(2) ^ 31)
    ])

    #Guarantee the external and internal chains are usable.
    discard result.derive(0)
    discard result.derive(1)
  except ValueError as e:
    raise e

#Grab the next valid key on this path.
proc next*(
  wallet: HDWallet,
  path: seq[uint32] = @[],
  last: uint32 = 0
): HDWallet {.forceCheck: [
  ValueError
].} =
  var
    pathWallet: HDWallet
    i: uint32 = last + 1
  try:
    pathWallet = wallet.derive(path)
  except ValueError as e:
    raise e

  while true:
    try:
      return pathWallet.derive(i)
    except ValueError:
      inc(i)
      if i == (uint32(2) ^ 31):
        raise newLoggedException(ValueError, "This path is out of non-hardened keys.")
      continue
