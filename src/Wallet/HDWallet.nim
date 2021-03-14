import stint

import ../lib/[Errors, Util, Hash]

import Ed25519, Address
export Ed25519, Address

import ../Network/Serialize/SerializeCommon

const
  #BIP 44 Coin Type.
  COIN_TYPE {.intdefine.}: uint32 = 5132
  #Ed25519's l value.
  l: StUInt[256] = "7237005577332262213973186563042994240857116359379907606001950938285454250989".parse(StUInt[256])
  #Hardened derivation threshold.
  HARDENED_THRESHOLD: uint32 = 1 shl 31

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
  secret: string
): HDWallet {.forceCheck: [
  ValueError
].} =
  if secret.len != 32:
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
  privateKey.data[31] = cuchar(byte(privateKey.data[31]) or       byte(0b01000000))

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
    child: string = childArg.toBinary(INT_LEN)
    #Is this a Hardened derivation?
    hardened: bool = childArg >= HARDENED_THRESHOLD
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

  #[
  Calculate the Private Key.
  WARNING: kL should probably be mod l here, as it's used as a scalar.
  That said, the codebase Meros uses as a reference, due to being an existing implementation, just uses the 32-byte variable.
  That said, this definitely isn't right; zR is explicitly % 2^256, and zL will overflow 32-bytes with enough of a depth.
  THAT said, the codebase says kL mod l must != 0, suggesting it's not naturally mod l.
  TL;DR the paper has an ambiguity; same ambiguity is dangerous; this should probably be mod l; it isn't.
  Why isn't Meros, a cryptocurrency, which needs to be secure and proper concerned?
  https://github.com/MerosCrypto/Meros/issues/266
  ]#
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
  if path.len >= (1 shl 20):
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
      uint32(44) + HARDENED_THRESHOLD,
      COIN_TYPE + HARDENED_THRESHOLD,
      account + HARDENED_THRESHOLD
    ])

    #Guarantee the external and internal chains are usable.
    discard result.derive(0)
    discard result.derive(1)
  except ValueError as e:
    raise e

#Grab the first valid key on this path.
proc first*(
  wallet: HDWallet
): HDWallet {.forceCheck: [].} =
  var i: uint32 = 0
  while true:
    try:
      return wallet.derive(i)
    except ValueError:
      inc(i)
      if i == HARDENED_THRESHOLD:
        panic("Couldn't derive the first account before hitting 2 ** 31.")

#Grab the next key on this path.
proc next*(
  wallet: HDWallet,
  start: uint32
): HDWallet {.forceCheck: [
  ValueError
].} =
  var i: uint32 = start
  while true:
    try:
      return wallet.derive(i)
    except ValueError:
      inc(i)
      if i == HARDENED_THRESHOLD:
        raise newLoggedException(ValueError, "Wallet is out of addresses.")
