#Errors objects.
import ../lib/objects/ErrorsObjs

#BLS Nimble package.
import mc_bls

#Hashes standard lib.
import hashes

#String utils standard lib.
import strutils

#Type aliases.
type
  BLSPrivateKey* = PrivateKey
  BLSPublicKey* = PublicKey
  BLSSignature* = Signature
  BLSAggregationInfo* = AggregationInfo

#Export the G1 and G2 lengths.
export G1_LEN, G2_LEN

#Constructors.
proc newBLSPrivateKey*(
  key: string
): BLSPrivateKey {.forceCheck: [
  BLSError
].} =
  try:
    result = newPrivateKey(key)
  except BLSError as e:
    raise e

proc newBLSPublicKey*(
  key: string = char(0b11000000) & newString(95)
): BLSPublicKey {.forceCheck: [
  BLSError
].} =
  try:
    result = newPublicKey(key)
  except BLSError as e:
    raise e

proc newBLSSignature*(
  sig: string = char(0b11000000) & newString(47)
): BLSSignature {.forceCheck: [
  BLSError
].} =
  try:
    result = newSignature(sig)
  except BLSError as e:
    raise e

proc newBLSAggregationInfo*(
  key: BLSPublicKey,
  msg: string
): BLSAggregationInfo {.forceCheck: [
  BLSError
].} =
  try:
    result = newAggregationInfo(key, msg)
  except BLSError as e:
    raise e

proc newBLSAggregationInfo*(
  keys: seq[BLSPublicKey],
  msg: string
): BLSAggregationInfo {.forceCheck: [
  BLSError
].} =
  try:
    result = newAggregationInfo(keys, msg)
  except BLSError as e:
    raise e

#Export member functions.
export toPublicKey, sign, verify, aggregate, serialize, isInf

#Equality functions.
proc `==`*(
  x: BLSPrivateKey,
  y: BLSPrivateKey
): bool {.inline, forceCheck: [].} =
  x.serialize() == y.serialize()

proc `==`*(
  x: BLSPublicKey,
  y: BLSPublicKey
): bool {.inline, forceCheck: [].} =
  x.serialize() == y.serialize()

proc `==`*(
  x: BLSSignature,
  y: BLSSignature
): bool {.inline, forceCheck: [].} =
  x.serialize() == y.serialize()

proc `!=`*(
  x: BLSPrivateKey,
  y: BLSPrivateKey
): bool {.inline, forceCheck: [].} =
  not (x.serialize() == y.serialize())

proc `!=`*(
  x: BLSPublicKey,
  y: BLSPublicKey
): bool {.inline, forceCheck: [].} =
  not (x.serialize() == y.serialize())

proc `!=`*(
  x: BLSSignature,
  y: BLSSignature
): bool {.inline, forceCheck: [].} =
  not (x.serialize() == y.serialize())

#Stringify functions.
proc `$`*(
  key: BLSPrivateKey
): string {.inline, forceCheck: [].} =
  key.serialize().toHex()

proc `$`*(
  key: BLSPublicKey
): string {.inline, forceCheck: [].} =
  key.serialize().toHex()

proc `$`*(
  sig: Signature
): string {.inline, forceCheck: [].} =
  sig.serialize().toHex()

#BLSPublicKey -> Hash so it can be used as an index in an Table.
proc hash*(
  key: BLSPublicKey
): Hash {.inline, forceCheck: [].} =
  hash(key.serialize())
