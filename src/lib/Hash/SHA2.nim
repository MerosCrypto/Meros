import nimcrypto
import nimcrypto/pbkdf2

import ForceCheck

import HashCommon

proc SHA2_256*(
  bytes: string
): Hash[256] {.forceCheck: [].} =
  var dataPtr: ptr byte
  if bytes.len != 0:
    dataPtr = cast[ptr byte](unsafeAddr bytes[0])
  result.data = sha256.digest(dataPtr, uint(bytes.len)).data

proc SHA2_512*(
  bytes: string
): Hash[512] {.forceCheck: [].} =
  var dataPtr: ptr byte
  if bytes.len != 0:
    dataPtr = cast[ptr byte](unsafeAddr bytes[0])
  result.data = sha512.digest(dataPtr, uint(bytes.len)).data

proc HMAC_SHA2_512*(
  key: string,
  bytes: string
): Hash[512] {.forceCheck: [].} =
  result.data = sha512.hmac(key, bytes).data

proc PDKDF2_HMAC_SHA2_512*(
  key: string,
  password: string
): Hash[512] {.forceCheck: [].} =
  var ctx: HMAC[sha512]
  discard pbkdf2(ctx, key, password, 2048, result.data)
