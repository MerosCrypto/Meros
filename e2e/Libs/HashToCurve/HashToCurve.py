#Subset of https://tools.ietf.org/html/draft-irtf-cfrg-hash-to-curve-09 built in a generic manner.
#This codebase only plans to implement/test the BLS curve functionality, as this isn't an elliptic curve library.
#This is a Meros independent reimplementation, and this functionality is necessary for it to contnue using Milagro.
#By keeping this on Milagro, while Meros moves to blst, we increase separation, and therefore accuracy and security.
#This is not constant time or further tested by Sage, instead using test vectors and comparison against blst.

from typing import Type, Callable, List, Any
from abc import ABC, abstractmethod

from e2e.Libs.HashToCurve.Elements import FieldElement, GroupElement

#pylint: disable=too-few-public-methods
class Curve:
  def __init__(
    self,
    fieldType: Type[FieldElement],
    groupType: Type[GroupElement],
    primeField: bool,
    p: int,
    m: int
  ) -> None:
    #pylint: disable=invalid-name
    self.FieldType: Type[FieldElement] = fieldType
    #pylint: disable=invalid-name
    self.GroupType: Type[GroupElement] = groupType
    self.p: int = p
    self.m: int = m
    self.q: int = p if primeField else (p ** m)

  @abstractmethod
  def mapToCurve(
    self,
    u: FieldElement
  ) -> GroupElement:
    ...

#pylint: disable=too-few-public-methods
class SuiteParameters(
  ABC
):
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
    #pylint: disable=invalid-name
    self.L: int = L
    self.expandMessage: Callable[[bytes, int], bytes] = expandMessage

  #https://tools.ietf.org/html/draft-irtf-cfrg-hash-to-curve-09#section-5.3
  def hashToField(
    self,
    msg: bytes,
    count: int
  ) -> List[List[int]]:
    #Steps 1-2
    uniform: bytes = self.expandMessage(msg, count * self.curve.m * self.L)

    #Steps 3-9.
    u: List[List[int]] = []
    for i in range(count):
      u.append([])
      for j in range(self.curve.m):
        elmOffset = self.L * (j + (i * self.curve.m))
        tv = uniform[elmOffset : elmOffset + self.L]
        u[-1].append(int.from_bytes(tv, "big") % self.curve.p)
    return u

  #https://tools.ietf.org/html/draft-irtf-cfrg-hash-to-curve-09#section-3
  def hashToCurve(
    self,
    msg: bytes
  ) -> Any:
    #Steps 1-3.
    #pylint: disable=invalid-name
    Qs: List[GroupElement] = [self.curve.mapToCurve(self.curve.FieldType(u)) for u in self.hashToField(msg, 2)]
    #Steps 4-6.
    return (Qs[0] + Qs[1]).clearCofactor()
