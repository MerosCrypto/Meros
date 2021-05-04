#Tests parity between the ed25519 library the and the new API-matching Ristretto/Ed25519.

import ed25519

import e2e.Libs.Ristretto.Ed25519 as ed

from e2e.Tests.Errors import TestError

def Ed25519Test() -> None:
  for i in range(256):
    keyA: ed25519.SigningKey = ed25519.SigningKey(bytes([i]) * 32)
    keyB: ed.SigningKey = ed.SigningKey(bytes([i]) * 32)
    if keyA.get_verifying_key().to_bytes() != keyB.get_verifying_key().to_bytes():
      raise TestError("Couldn't get the same public key from our ed25519 API reimplementation as the actual library.")
    if keyA.sign(b"abc") != keyB.sign(b"abc"):
      raise TestError("Couldn't get the same signature from our ed25519 API reimplementation as the actual library.")
