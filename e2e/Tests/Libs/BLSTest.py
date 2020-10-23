from e2e.Libs.BLS import PrivateKey, AggregationInfo

#Basic sanity test.
def BLSTest() -> None:
  key: PrivateKey = PrivateKey(0)
  if not key.sign(b"abc").verify(AggregationInfo(key.toPublicKey(), b"abc")):
    raise TestError("Couldn't sign and verify a BLS signature from Python.")
