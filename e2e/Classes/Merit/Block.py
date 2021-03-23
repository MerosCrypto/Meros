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
    other: Any
  ) -> bool:
    if not isinstance(other, Block):
      raise Exception("Comparison between Block and non-Block.")

    selfBlock: Dict[str, Any] = self.toJSON()
    otherBlock: Dict[str, Any] = other.toJSON()

    for block in [selfBlock, otherBlock]:
      try:
        del block["header"]["packets"]
      except KeyError:
        pass
      try:
        del block["removals"]
      except KeyError:
        pass
    return otherBlock == selfBlock

  def __ne__(
    self,
    other: Any
  ) -> bool:
    return not self == other

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
