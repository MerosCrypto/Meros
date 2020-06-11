from typing import Dict, Any
from abc import ABC, abstractmethod

class Transaction(
  ABC
):
  hash: bytes

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
