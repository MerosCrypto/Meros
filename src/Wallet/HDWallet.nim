import stint

#Directly import mc_ristretto for more control over Elliptic curve operations.
import mc_ristretto except sign

import ../lib/[Errors, Util, Hash]

import Ristretto, Address
export Ristretto, Address

import ../Network/Serialize/SerializeCommon

const
  #BIP 44 Coin Type.
  COIN_TYPE {.intdefine.}: uint32 = 5132
  #Hardened derivation threshold.
  HARDENED_THRESHOLD: uint32 = 1 shl 31

type
  HDWallet* = object
    chainCode*: Hash[256]
    privateKey*: RistrettoPrivateKey
    publicKey*: RistrettoPublicKey
    address*: string

  HDPublic* = object
    #Key and matching chain code.
    key*: RistrettoPublicKey
    chainCode*: Hash[256]
    #Index this key was of its parent.
    index*: uint32

let identity: RistrettoPublicKey = newScalar(newSeq[byte](32)).toPoint()

func sign*(
  wallet: HDWallet,
  msg: string
): seq[byte] {.inline, forceCheck: [].} =
  wallet.privateKey.sign(msg)

proc newHDWallet*(
  secret: string
): HDWallet {.forceCheck: [
  ValueError
].} =
  if secret.len != 32:
    raise newLoggedException(ValueError, "Invalid length secret passed to newHDWallet.")

  #Create the Private Key.
  var privateKeyBytes: seq[byte] = @(SHA2_512(secret).data)
  if (byte(privateKeyBytes[31]) and 0b00100000) != 0:
    raise newLoggedException(ValueError, "Secret generated an invalid private key.")
  privateKeyBytes[0]  = byte(privateKeyBytes[0])  and (not byte(0b00000111))
  privateKeyBytes[31] = byte(privateKeyBytes[31]) and (not byte(0b10000000))
  privateKeyBytes[31] = byte(privateKeyBytes[31]) or       byte(0b01000000)

  #Create the Public Key.
  var
    #This performs a mod l on kL which the BIP32-Ed25519 doesn't specify. That said, it's required to form a valid private key.
    privateKey: RistrettoPrivateKey = newRistrettoPrivateKey(privateKeyBytes)
    publicKey: RistrettoPublicKey = privateKey.toPublicKey()

  result = HDWallet(
    #Set the Wallet fields.
    privateKey: privateKey,
    publicKey: publicKey,
    address: newAddress(AddressType.PublicKey, cast[string](publicKey.serialize())),

    #Create the chain code.
    chainCode: SHA2_256('\1' & secret)
  )

#Shim since StInt only provides toByteArrayBE.
func toByteArrayLE[bits: static int](
  x: StUInt[bits]
): seq[byte] {.inline, forceCheck: [].} =
  #This is absolutely horrendous.
  #reverse takes a string yet StInt gives an array.
  #We convert that to a seq, cast to a string, reverse, cast back to a seq[byte], and return that.
  cast[seq[byte]](cast[string](@(x.toByteArrayBE())).reverse())

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
    pPrivateKey: string = cast[string](wallet.privateKey.serialize())
    pPrivateKeyL: array[32, byte]
    pPrivateKeyR: array[32, byte]
    pPublicKey: string = cast[string](wallet.publicKey.serialize())

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
  This performs a mod l on kL which the BIP32-Ed25519 doesn't specify. That said, it's required to form a valid private key.
  ]#
  var kLBytes: seq[byte]
  try:
    kLBytes = newScalar(((readUIntBE[256](zL) * 8) + readUIntBE[256](pPrivateKeyL)).toByteArrayLE()).serialize()
    if kLBytes == newSeq[byte](32):
      raise newLoggedException(Exception, "Deriving this child key produced an unusable PrivateKey.")
  except ValueError as e:
    panic("Couldn't construct a scalar from a 32-byte value: " & e.msg)
  #Needed due to mc_ristretto using ValueError as well.
  except Exception as e:
    raise newException(ValueError, e.msg)

  kR = readUIntBE[256](zR) + readUIntBE[256](pPrivateKeyR)

  #Set the Private and Public keys.
  var
    privateKey: RistrettoPrivateKey = newRistrettoPrivateKey(kLBytes & @(kR.toByteArrayLE()))
    publicKey: RistrettoPublicKey = privateKey.toPublicKey()

  result = HDWallet(
    #Set the Wallet fields.
    privateKey: privateKey,
    publicKey: publicKey,
    address: newAddress(AddressType.PublicKey, cast[string](publicKey.serialize())),

    #Set the chain code.
    chainCode: chainCode
  )

proc derivePublic*(
  parent: HDPublic,
  child: uint32
): HDPublic {.forceCheck: [
  ValueError
].} =
  result.index = child

  var
    Z: Hash[512]
    chainCodeExtended: Hash[512]
  if child >= HARDENED_THRESHOLD:
    panic("Asked to derive a public key with a hardened threshold.")
  else:
    Z = HMAC_SHA2_512(parent.chainCode.serialize(), '\2' & cast[string](parent.key.serialize()) & child.toBinary(INT_LEN))
    chainCodeExtended = HMAC_SHA2_512(parent.chainCode.serialize(), '\3' & cast[string](parent.key.serialize()) & child.toBinary(INT_LEN))
    copyMem(addr result.chainCode.data[0], addr chainCodeExtended.data[32], 32)

  var zL: array[32, byte]
  for i in 0 ..< 28:
    zL[31 - i] = Z.data[i]

  try:
    result.key = newScalar((readUIntBE[256](zL) * 8).toByteArrayLE()).toPoint() + parent.key
  except ValueError as e:
    panic("Couldn't construct a scalar from a 32-byte value: " & e.msg)

  if result.key == identity:
    raise newLoggedException(ValueError, "Deriving this child key produced an unusable PublicKey.")

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
  parent: HDPublic,
  start: uint32
): HDPublic {.forceCheck: [
  ValueError
].} =
  var i: uint32 = start
  while true:
    try:
      result = parent.derivePublic(i)
      break
    #Keep going until we hit a valid address.
    except ValueError:
      i += 1
      if i >= (1 shl 31):
        raise newLoggedException(ValueError, "Couldn't derive the next key as this account is out of non-hardened keys.")
      continue
