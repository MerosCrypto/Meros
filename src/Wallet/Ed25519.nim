import hashes

import mc_ed25519

import ../lib/[Errors, Util, Hash]

#Block 0 public keys from being signed for.
#Allows creation of a single, consolidated burn address.
#Also skips over an extremely feasible mistake.
const ZERO_KEY: array[32, cuchar] = [
  #Generally, we'd only need to cast the first array entry. Unfortunately, cuchar doesn't have this property.
  cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0),
  cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0),
  cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0),
  cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0), cuchar(0)
]

#SIGN_PREFIX applied to every message, stopping cross-network replays.
const SIGN_PREFIX {.strdefine.}: string = "MEROS"

#Export the Private/Public Key objects (with a prefix).
type
  EdPrivateKey* = object
    data*: PrivateKey
  EdPublicKey* = object
    data*: PublicKey
  EdSignature* = object
    data*: array[64, byte]

proc newEdPublicKey*(
  key: string
): EdPublicKey {.forceCheck: [].} =
  if key.len != 32:
    panic("Key which wasn't 32 bytes was passed to newEdPublicKey.")
  copyMem(addr result.data[0], unsafeAddr key[0], 32)

proc newEdSignature*(
  sig: string
): EdSignature {.forceCheck: [].} =
  if sig.len != 64:
    panic("Key which wasn't 64 bytes was passed to newEdPublicKey.")
  copyMem(addr result.data[0], unsafeAddr sig[0], 64)

proc toPublicKey*(
  key: EdPrivateKey
): EdPublicKey {.forceCheck: [].} =
  #Public Key point.
  var publicKeyPoint3: ptr Point3 = cast[ptr Point3](alloc0(sizeof(Point3)))

  #Multiply the Public Key against the base.
  multiplyBase(publicKeyPoint3, unsafeAddr key.data[0])
  serialize(addr result.data[0], publicKeyPoint3)

#Sign a message with the sign prefix.
func sign*(
  privKeyArg: EdPrivateKey,
  pubKeyArg: EdPublicKey,
  msgArg: string
): EdSignature {.forceCheck: [].} =
  #Extract the arguments.
  var
    privKey: EdPrivateKey = privKeyArg
    pubKey: EdPublicKey = pubKeyArg
    msg: string = SIGN_PREFIX & msgArg

  #Create the signature.
  sign(
    cast[ptr cuchar](addr result.data[0]),
    cast[ptr cuchar](addr msg[0]),
    csize(msg.len),
    cast[ptr cuchar](addr pubKey.data[0]),
    cast[ptr cuchar](addr privKey.data[0])
  )

#Verify a message with the sign prefix.
func verify*(
  keyArg: EdPublicKey,
  msgArg: string,
  sigArg: EdSignature
): bool {.forceCheck: [].} =
  if keyArg.data == ZERO_KEY:
    return false

  #Extract the argsuments.
  var
    key: EdPublicKey = keyArg
    msg: string = SIGN_PREFIX & msgArg
    sig: EdSignature = sigArg

  #Verify the signature.
  if verify(
    cast[ptr cuchar](addr sig.data[0]),
    cast[ptr cuchar](addr msg[0]),
    csize(msg.len),
    addr key.data[0]
  ) == 1:
    return true

  result = false

func serialize*(
  data: EdPrivateKey or EdPublicKey or EdSignature
): string {.forceCheck: [].} =
  result = newString(data.data.len)
  copyMem(addr result[0], unsafeAddr data.data[0], data.data.len)

func `$`*(
  data: EdPrivateKey or EdPublicKey or EdSignature
): string {.inline, forceCheck: [].} =
  data.serialize().toHex()

#Aggregate Public Keys for MuSig.
proc aggregate*(
  keys: var seq[EdPublicKey]
): EdPublicKey {.forceCheck: [].} =
  if keys.len == 1:
    return keys[0]

  var
    bytes: string
    l: Hash.Hash[256]
    keyHash: Hash.Hash[256]
    keyPoint: Point3
    a: Point2
    tempRes: PointP1P1
    tempCached: PointCached
    res: Point3

  for key in keys:
    bytes &= key.serialize()
  l = SHA2_256(bytes)
  bytes = newString(64)

  for k in 0 ..< keys.len:
    keyHash = SHA2_256(l.serialize() & keys[k].serialize())
    copyMem(addr bytes[0], addr keyHash.data[0], 32)
    reduceScalar(cast[ptr cuchar](addr bytes[0]))
    copyMem(addr keyHash.data[0], addr bytes[0], 32)

    keyToNegativePoint(addr keyPoint, addr keys[k].data[0])
    serialize(addr bytes[0], addr keyPoint)
    keyToNegativePoint(addr keyPoint, cast[ptr cuchar](addr bytes[0]))

    var blankScalar: array[32, cuchar]
    multiplyScalar(
      addr a,
      cast[ptr cuchar](addr keyHash.data[0]),
      addr keyPoint,
      addr blankScalar[0]
    )

    serialize(addr bytes[0], addr a)
    keyToNegativePoint(addr keyPoint, cast[ptr cuchar](addr bytes[0]))
    serialize(addr bytes[0], addr keyPoint)
    keyToNegativePoint(addr keyPoint, cast[ptr cuchar](addr bytes[0]))

    if k == 0:
      res = keyPoint
    else:
      p3ToCached(addr tempCached, addr keyPoint)
      add(addr tempRes, addr res, addr tempCached)
      p1p1ToP3(addr res, addr tempRes)

  serialize(addr result.data[0], addr res)

proc hash*(
  key: EdPublicKey
): hashes.Hash {.inline, forceCheck: [].} =
  for b in key.data:
    result = result !& int(b)
  result = !$ result
