import hashes
import strutils

import mc_bls
export G1_LEN, G2_LEN, toPublicKey, sign, verify, aggregate, serialize, isInf

import ../lib/objects/ErrorObjs

#[
Type aliases for mc_bls.
mc_bls solely calls keys, keys.
As Meros also uses Ed25519, there's a requirement to distinguish.
Hence the BLS/Ed prefixed.
]#
type
  BLSPrivateKey* = PrivateKey
  BLSPublicKey* = PublicKey
  BLSSignature* = Signature
  BLSAggregationInfo* = AggregationInfo

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
