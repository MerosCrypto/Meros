from e2e.Libs.BLS import PrivateKey, AggregationInfo

from e2e.Tests.Errors import TestError

#Basic sanity test.
def BLSTest() -> None:
  key: PrivateKey = PrivateKey(0)
  if not key.sign(b"abc").verify(AggregationInfo(key.toPublicKey(), b"abc")):
    raise TestError("Couldn't sign and verify a BLS signature from Python.")
  if key.sign(b"abc").verify(AggregationInfo(key.toPublicKey(), b"def")):
    raise TestError("Could verify a BLS signature with anything in Python.")
