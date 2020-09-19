#Subset of https://tools.ietf.org/html/draft-irtf-cfrg-hash-to-curve-09 built in a generic manner.

from typing import Type, TypeVar, Callable, List, Any
from abc import ABC, abstractmethod

from e2e.Libs.HashToCurve.Elements import FieldElement, GroupElement

#https://tools.ietf.org/html/draft-irtf-cfrg-hash-to-curve-09#section-5.4.1
def expandMessageXMD(
  H: Any,
  dst: str,
  msg: bytes,
  outLen: int
) -> bytes:
  #Steps 1-2.
  ell: int = ((outLen + H.digest_size) - 1) // H.digest_size
  if ell > 255:
    raise Exception("Invalid XMD output length set given the hash function.")

  #Steps 3-4.
  if len(dst) > 255:
    raise Exception("Invalid DST.")
  dstPrime: bytes = dst.encode("utf-8") + len(dst).to_bytes(1, "big")
  zPad: bytes = bytes([0] * H.block_size)
  if outLen > 65535:
    raise Exception("Invalid XMD output length.")

  #Steps 5-6.
  msgPrime: bytes = zPad + msg + outLen.to_bytes(2, "big") + bytes([0]) + dstPrime

  #Steps 7-8.
  #b0
  b: List[bytes] = [H(msgPrime).digest()]
  #b1
  b.append(H(b[0] + bytes([1]) + dstPrime).digest())

  #Steps 9-10.
  for i in range(2, ell):
    b.append(
      H(
        bytes([b[0][i] ^ b[-1][i] for i in range(len(b))]) +
        i.to_bytes(1, "big") +
        dstPrime
      )
    )

  #Steps 11-12.
  return (b"".join(b[1:]))[0 : outLen]

class Curve:
  def __init__(
    self,
    fieldType: Type[FieldElement],
    groupType: Type[GroupElement],
    primeField: bool,
    p: int,
    m: int
  ) -> None:
    self.FieldType: Type[FieldElement] = fieldType
    self.GroupType: Type[GroupElement] = groupType
    self.p: int = p
    self.m: int = m
    self.q: int = p if primeField else (p ** m)

class SuiteParameters(ABC):
  def __init__(
    self,
    curve: Curve,
    dst: str,
    k: int,
    L: int,
    expandMessage: Callable[[bytes, int], bytes]
  ) -> None:
    self.curve: Curve = curve
    self.dst: str = dst
    self.k: int = k
    self.L: int = L
    self.expandMessage: Callable[[bytes, int], bytes] = expandMessage

  @abstractmethod
  def mapToCurve(
    u: FieldElement
  ) -> GroupElement:
    ...

#https://tools.ietf.org/html/draft-irtf-cfrg-hash-to-curve-09#section-5.3
def hashToField(
  params: SuiteParameters,
  msg: bytes,
  count: int,
) -> List[Any]:
  #Steps 1-2
  uniform: bytes = params.expandMessage(msg, count * params.curve.m * params.L)

  #Steps 3-9.
  u: List[Any] = []
  for i in range(count):
    u.append(params.curve.FieldType())
    for j in range(params.curve.m):
      elmOffset = params.L * (j + (i * params.curve.m))
      tv = uniform[elmOffset : elmOffset + params.L]
      u[-1].value.append(int.from_bytes(tv, "big") % params.curve.p)
  return u

#https://tools.ietf.org/html/draft-irtf-cfrg-hash-to-curve-09#section-3
def hashToCurve(
  suite: SuiteParameters,
  msg: bytes
) -> Any:
  #Steps 1-3.
  Qs: List[GroupElement] = [suite.mapToCurve(u) for u in hashToField(suite, msg, 2)]
  #Steps 4-6.
  return (Qs[0] + Qs[1]).clearCofactor()

raise Exception("This file isn't tested.")
