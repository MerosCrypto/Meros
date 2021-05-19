from typing import Dict, Any
import json

from pytest import raises

from e2e.Libs.Ristretto.Ristretto import BASEPOINT, RistrettoScalar, RistrettoPoint, hashToCurve

from e2e.Tests.Errors import TestError

def RistrettoTest() -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Libs/Ristretto.json", "r") as file:
    vectors = json.loads(file.read())

  basepoint: RistrettoPoint = RistrettoPoint(BASEPOINT)
  for b in range(len(vectors["multiples"])):
    #Encoding.
    if vectors["multiples"][b] != (basepoint * RistrettoScalar(b)).serialize().hex():
      raise TestError("Basepoint multiple was incorrect.")
    #Decoding.
    if vectors["multiples"][b] != RistrettoPoint(bytes.fromhex(vectors["multiples"][b])).serialize().hex():
      raise TestError("Couldn't encode and decode.")

  #Test the equality operator.
  if RistrettoPoint(bytes.fromhex(vectors["multiples"][0])) != RistrettoPoint(bytes.fromhex(vectors["multiples"][0])):
    raise Exception("Equal points were considered inequal.")
  if RistrettoPoint(bytes.fromhex(vectors["multiples"][0])) == RistrettoPoint(bytes.fromhex(vectors["multiples"][1])):
    raise Exception("Inequal points were considered equal.")

  #Test decoding invalid points.
  for point in vectors["badEncodings"]:
    with raises(Exception):
      RistrettoPoint(bytes.fromhex(point))

  #Test hash to curve. It's not used anywhere in Meros, yet it ensures accuracy of our Ristretto implementation.
  for hTP in vectors["hashToPoints"]:
    if hTP[1] != hashToCurve(hTP[0].encode("utf-8")).serialize().hex():
      raise TestError("Hash to point was incorrect.")
