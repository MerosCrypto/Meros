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

proc hasMultipleKeys*(
  keys: seq[EdPrivateKey or EdPublicKey]
): bool {.forceCheck: [].} =
  #Check if this is a single key. If so, return false.
  var uniqueKeys: seq[EdPublicKey] = @[]
  for key in keys:
    if key notin uniqueKeys:
      uniqueKeys.add(key)
  return uniqueKeys.len != 1

#Generates the `a` value to use for each key.
#Returns a Hash[512] as we don't have a good scalar type and the datas already in a Hash[512].
#The EdPrivateKey type, which is effectively a scalar, mirrors Hash[256]'s instantiated type definition.
#While this would save 32-bytes, it'll be pushed off the stack soon enough.
#Internally, pointers to raw bytes are used anyways.
proc generateAs(
  keys: seq[EdPublicKey]
): seq[Hash.Hash[512]] {.forceCheck: [].} =
  var L: string = ""
  for key in keys:
    L &= key.serialize()
  L = Blake512(L).serialize()

  for key in keys:
    result.add(Blake512("agg" & L & key.serialize()))
    reduceScalar(cast[ptr cuchar](addr result[^1].data[0]))

#Aggregate Public Keys for MuSig.
proc aggregate*(
  keys: seq[EdPublicKey]
): EdPublicKey {.forceCheck: [].} =
  if not keys.hasMultipleKeys:
    return keys[0]

  var
    As: seq[Hash.Hash[512]] = keys.generateAs()
    keyPoint: Point3
    bytes: string = newString(64)
    p2: Point2
    tempRes: PointP1P1
    tempCached: PointCached
    res: Point3

  for k in 0 ..< keys.len:
    var key: EdPublicKey = keys[k]
    keyToNegativePoint(addr keyPoint, addr key.data[0])
    serialize(addr bytes[0], addr keyPoint)
    keyToNegativePoint(addr keyPoint, cast[ptr cuchar](addr bytes[0]))

    var blankScalar: array[32, cuchar]
    multiplyScalar(
      addr p2,
      cast[ptr cuchar](addr As[k].data[0]),
      addr keyPoint,
      addr blankScalar[0]
    )

    serialize(addr bytes[0], addr p2)
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

#Private key aggregation to create a private key matching the MuSig public key aggregation.
#Insecure in the scope of MuSig as it is solely meant to be used by internally known private keys.
#Not even close to what MuSig does.
proc aggregate*(
  keys: seq[EdPrivateKey]
): EdPrivateKey {.forceCheck: [].} =
  var pubKeys: seq[EdPublicKey] = @[]
  for key in keys:
    pubKeys.add(key.toPublicKey())

  var
    As: seq[Hash.Hash[512]] = generateAs(pubKeys)
    res: string = newString(32)
  for k in 0 ..< keys.len:
    var key: EdPrivateKey = keys[k]
    mulAdd(cast[ptr cuchar](addr res[0]), addr key.data[0], cast[ptr cuchar](addr As[k].data[0]), cast[ptr cuchar](addr res[0]))

  #Traditional secret key expansion would be H512(secret), with the left half mod l.
  #We have a scalar, not a secret. In response, H512(scalar). Then, the scalar is the left half already.
  #This leaves us with just the right half left, which is still the right half of the H512 result.
  #We could also call urandom, which wouldn't be deterministic, or call H256 and just use that.
  var expanded: Hash.Hash[512] = Blake512(res)
  copyMem(addr result.data[0], addr res[0], 32)
  copyMem(addr result.data[32], addr expanded.data[32], 32)

proc hash*(
  key: EdPublicKey
): hashes.Hash {.forceCheck: [].} =
  for b in key.data:
    result = result !& int(b)
  result = !$ result
