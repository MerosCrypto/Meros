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

  #Create the Private and Public Keys.
  var
    privateKey: RistrettoPrivateKey = newRistrettoPrivateKey(@(SHA2_512(secret).data))
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
    #Parent properties, serialized in little endian.
    pChainCode: string = wallet.chainCode.serialize()
    pPrivateKey: seq[byte] = wallet.privateKey.serialize()
    pPrivateKeyR: array[32, byte]
    pPublicKey: string = cast[string](wallet.publicKey.serialize())

    #Child index, in little endian.
    child: string = childArg.toBinary(INT_LEN)
    #Is this a Hardened derivation?
    hardened: bool = childArg >= HARDENED_THRESHOLD
  for i in 0 ..< 32:
    pPrivateKeyR[31 - i] = pPrivateKey[32 + i]

  #Calculate Z and the Chaincode.
  var
    Z: Hash[512]
    chainCodeExtended: Hash[512]
    chainCode: Hash[256]
  if hardened:
    Z = HMAC_SHA2_512(pChainCode, '\0' & cast[string](pPrivateKey) & child)
    chainCodeExtended = HMAC_SHA2_512(pChainCode, '\1' & cast[string](pPrivateKey) & child)
    copyMem(addr chainCode.data[0], addr chainCodeExtended.data[32], 32)
  else:
    Z = HMAC_SHA2_512(pChainCode, '\2' & pPublicKey & child)
    chainCodeExtended = HMAC_SHA2_512(pChainCode, '\3' & pPublicKey & child)
    copyMem(addr chainCode.data[0], addr chainCodeExtended.data[32], 32)

  #Calculate the Private Key.
  var cScalar: Scalar
  try:
    let
      zScalar: Scalar = newScalar(Z.data[0 ..< 32])
      pScalar: Scalar = newScalar(pPrivateKey[0 ..< 32])
    cScalar = zScalar + pScalar
  except ValueError as e:
    panic("Couldn't construct a scalar from a 32-byte value: " & e.msg)
  #Isn't the chance of this equivalent to randomly finding a specific key?
  #If this isn't needed, a lot of exception handling can be removed.
  #Remnant from BIP32-Ed25519.
  if cScalar.serialize() == newSeq[byte](32):
    raise newLoggedException(ValueError, "Deriving this child key produced an unusable PrivateKey.")

  #Nonce variables.
  var
    zR: array[32, byte]
    kR: StUInt[256]
  for i in 0 ..< 32:
    zR[31 - i] = Z.data[32 + i]
  kR = readUIntBE[256](zR) + readUIntBE[256](pPrivateKeyR)

  #Set the Private and Public keys.
  var
    privateKey: RistrettoPrivateKey = newRistrettoPrivateKey(cScalar.serialize() & @(kR.toByteArrayLE()))
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

  var zScalar: Scalar
  try:
    zScalar = newScalar(Z.data[0 ..< 32])
  except ValueError as e:
    panic("Couldn't construct a scalar from a 32-byte value: " & e.msg)
  result.key = zScalar.toPoint() + parent.key

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
    raise newLoggedException(ValueError, "Derivation path is too deep.")

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
