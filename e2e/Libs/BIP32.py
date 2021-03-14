from typing import List, Any
import hashlib, hmac

import e2e.Libs.ed25519 as ed

HARDENED_THRESHOLD: int = 1 << 31

def hmac512(
  key: bytes,
  msg: bytes
) -> bytes:
  return hmac.new(key, msg, hashlib.sha512).digest()

def derive(
  secret: bytes,
  path: List[int]
) -> bytes:
  #Clamp the secret.
  k: bytes = ed.H(secret)
  kL: bytes = k[:32]
  kR: bytes = k[32:]
  if kR[31] & 0b00100000 != 0:
    raise Exception("Invalid secret to derive from.")
  kLArr: bytearray = bytearray(kL)
  kLArr[0] = (kL[0] >> 3) << 3
  kLArr[31] = (kL[31] << 1) >> 1
  kLArr[31] = kL[31] | (1 << 6)
  kL = bytes(kLArr)
  k = kL + kR

  #Parent public key/chain code.
  A: bytes = ed.encodepoint(ed.scalarmult(ed.B, ed.decodeint(kL)))
  c: bytes = hashlib.sha256(bytes([1]) + secret).digest()

  #Derive each child.
  for i in path:
    iBytes: bytes = i.to_bytes(4, "little")
    Z: bytes
    if i < HARDENED_THRESHOLD:
      Z = hmac512(c, bytes([2]) + A + iBytes)
      c = hmac512(c, bytes([3]) + A + iBytes)
    else:
      Z = hmac512(c, bytes([0]) + A + iBytes)
      c = hmac512(c, bytes([1]) + A + iBytes)

    zL: bytearray = bytearray(Z[:28])
    for _ in range(4):
      zL.append(0)
    zR: bytes = Z[32:]
    kL = ed.encodeint((8 * ed.decodeint(bytes(zL))) + ed.decodeint(kL))
    if kL == 0:
      raise Exception("Invalid child.")
    #This modulus should be redundant given encodeint only uses the latter 32 bytes.
    kR = ed.encodeint((ed.decodeint(zR) + ed.decodeint(kR)) % (1 << 256))
    k = kL + kR

  return k
