import hashes
import strutils

import stint

import mc_bls
export SCALAR_LEN, G1_LEN, G2_LEN, toPublicKey, verify, aggregate, serialize, isInf

import ../lib/objects/ErrorObjs

const
  r: StUInt[256] = "0x73EDA753299D7D483339D80809A1D80553BDA402FFFE5BFEFFFFFFFF00000001".parse(StUInt[256], 16)
  DST {.strdefine.}: string = "MEROS-V00-CS01-with-BLS12381G1_XMD:SHA-256_SSWU_RO_"

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
  keyArg: string
): BLSPrivateKey {.forceCheck: [
  BLSError
].} =
  if keyArg.len != SCALAR_LEN:
    raise newException(BLSError, "Invalid private key length.")

  #[
  Mod by the curve order (r). Needed to create a valid scalar.
  Milagro does this. blst doesn't automatically, and mc_bls doesn't by extension.
  This should arguably be in mc_bls. That said, blst doesn't provide a scalar modulus.
  This leaves mc_bls closer to blst and uses stint, which is already here.
  This may be moved in the future.
  ]#
  var
    key: string = keyArg
    keyArr: array[SCALAR_LEN, byte]
  try:
    keyArr = (StUInt[SCALAR_LEN * 8].fromBytesBE(cast[seq[byte]](key)) mod r).toBytesBE()
  except DivByZeroError as e:
    doAssert(false, "Divided by zero when applying the moduli of the curve order: " & e.msg)
  copyMem(addr key[0], addr keyArr[0], SCALAR_LEN)

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
    result = newAggregationInfo(key, msg, DST)
  except BLSError as e:
    raise e

template newBLSAggregationInfo*(
  keys: seq[BLSPublicKey],
  msg: string
): BLSAggregationInfo =
  newBLSAggregationInfo(keys.aggregate(), msg)

proc sign*(
  key: BLSPrivateKey,
  msg: string
): BLSSignature {.inline, forceCheck: [].} =
  key.sign(msg, DST)

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
