from typing import Dict, Any
from abc import ABC, abstractmethod

from e2e.Libs.BLS import Signature

class Element(
  ABC
):
  prefix: bytes
  holder: int

  @abstractmethod
  def signatureSerialize(
    self
  ) -> bytes:
    pass

  @abstractmethod
  def serialize(
    self
  ) -> bytes:
    pass

  @abstractmethod
  def toJSON(
    self
  ) -> Dict[str, Any]:
    pass

class SignedElement(
  ABC
):
  signature: Signature

  @abstractmethod
  def signedSerialize(
    self
  ) -> bytes:
    pass

  @abstractmethod
  def toSignedJSON(
    self
  ) -> Dict[str, Any]:
    pass
