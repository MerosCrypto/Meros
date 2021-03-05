from typing import Dict, Any

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody

class Block:
  def __init__(
    self,
    header: BlockHeader,
    body: BlockBody
  ) -> None:
    self.header: BlockHeader = header
    self.body: BlockBody = body
  
  def __eq__(
    self,
    other
  ) -> bool:
    if not isinstance(other, self.__class__):
      return False
    otherBlock: Dict[str, Any]
    selfBlock: Dict[str, Any]
    otherBlock, selfBlock = other.toJSON(), self.toJSON()
    try:
      del selfBlock["header"]["packets"]
    except KeyError:
      pass
    try:
      del otherBlock["header"]["packets"]
    except KeyError:
      pass
    try:
      del selfBlock["removals"]
    except KeyError:
      pass
    try:
      del otherBlock["header"]["packets"]
    except KeyError:
      pass
    return otherBlock == selfBlock
  
  def __ne__(
    self,
    other
  ) -> bool:
    if isinstance(other, self.__class__):
      return self.toJSON() != other.toJSON()
    return True

  def mine(
    self,
    privKey: PrivateKey,
    difficulty: int
  ) -> None:
    self.header.mine(privKey, difficulty)

  def toJSON(
    self
  ) -> Dict[str, Any]:
    result: Dict[str, Any] = self.body.toJSON()
    result["header"] = self.header.toJSON()
    result["hash"] = self.header.hash.hex().upper()
    return result

  @staticmethod
  def fromJSON(
    json: Dict[str, Any]
  ) -> Any:
    return Block(
      BlockHeader.fromJSON(json["header"]),
      BlockBody.fromJSON(json)
    )
