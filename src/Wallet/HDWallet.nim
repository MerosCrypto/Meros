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
  secretArg: string
): HDWallet {.forceCheck: [
  ValueError
].} =
  if secretArg.len != 64:
    raise newLoggedException(ValueError, "Invalid length seed passed to newHDWallet.")

  let
    #Differentiate the seed from BLS.
    secret = Blake512("Ristretto" & secretArg)
    #Create the Private and Public Keys.
    privateKey: RistrettoPrivateKey = newRistrettoPrivateKey(cast[seq[byte]](secret.serialize()))
    publicKey: RistrettoPublicKey = privateKey.toPublicKey()

  result = HDWallet(
    #Set the Wallet fields.
    privateKey: privateKey,
    publicKey: publicKey,
    address: newAddress(AddressType.PublicKey, cast[string](publicKey.serialize())),

    #Create the chain code.
    #Doesn't use the secret, yet rather the serialized private key, to enable recovery from just the root private key.
    #Allows loss of seed yet preservation of key to recover the entire tree, however unlikely that is.
    #BIP32 has equivalence between the two whereas we perform a wide reduction, hence why we have to choose which path to take.
    chainCode: Blake256("ChainCode" & cast[string](privateKey.serialize()))
  )

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
    pPublicKey: string = cast[string](wallet.publicKey.serialize())

    #Child index, in little endian.
    child: string = childArg.toBinary(INT_LEN)
    #Is this a Hardened derivation?
    hardened: bool = childArg >= HARDENED_THRESHOLD

  #Calculate I.
  #I here is solely used for the new scalar with the chain code having its own DST'd hash.
  var
    I: Hash[512]
    chainCode: Hash[256]
  if hardened:
    #Blake2 doesn't require a HMAC mode yet the chain code is required for privacy.
    #Else it'd be trivial enough to calculate if a key was a child of a parent.
    #While such a case shouldn't come up with Meros, which uses siblings, this should be protected.
    #DST'd as we need a 512-bit scalar for guaranteed viability (safe reduction) AND the 256-bit chain code value.
    #Breaks from BIP32 yet its a legacy spec already needing implementation against Ristretto by libraries, giving us leeway.
    #Schnorrkel does have its own HDKD scheme, also doing multiple hashes with DSTs, yet it's not worth matching.
    I = Blake512("Key" & pChainCode & cast[string](pPrivateKey) & child)
    chainCode = Blake256("ChainCode" & pChainCode & cast[string](pPrivateKey) & child)
  else:
    I = Blake512("Key" & pChainCode & pPublicKey & child)
    chainCode = Blake256("ChainCode" & pChainCode & pPublicKey & child)

  #Calculate the Private Key.
  var privateKey: RistrettoPrivateKey
  try:
    privateKey = newScalar(@(I.data)) + newScalar(pPrivateKey)
  except ValueError as e:
    panic("Couldn't construct a scalar from a 64-byte value: " & e.msg)
  if privateKey.serialize() == newSeq[byte](32):
    raise newLoggedException(ValueError, "Deriving this child key produced an unusable PrivateKey (zero).")

  let publicKey = privateKey.toPublicKey()
  result = HDWallet(
    privateKey: privateKey,
    publicKey: publicKey,
    address: newAddress(AddressType.PublicKey, cast[string](publicKey.serialize())),
    chainCode: chainCode
  )

proc derivePublic*(
  parent: HDPublic,
  child: uint32
): HDPublic {.forceCheck: [
  ValueError
].} =
  if child >= HARDENED_THRESHOLD:
    panic("Asked to derive a public key with a hardened threshold.")
  result.index = child

  let
    pPublicKey = cast[string](parent.key.serialize())
    I: Hash[512] = Blake512("Key" & parent.chainCode.serialize() & pPublicKey & child.toBinary(INT_LEN))
  result.chainCode = Blake256("ChainCode" & parent.chainCode.serialize() & pPublicKey & child.toBinary(INT_LEN))

  var scalar: Scalar
  try:
    scalar = newScalar(@(I.data))
  except ValueError as e:
    panic("Couldn't construct a scalar from a 32-byte value: " & e.msg)
  result.key = scalar.toPoint() + parent.key

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

#Get a specific BIP 44 account.
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
