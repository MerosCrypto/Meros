#Types.
from typing import Dict, Any

#BLS lib.
from e2e.Libs.BLS import PrivateKey

#BlockHeader and BlockBody classes.
from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody

#Block class.
class Block:
  #Constructor.
  def __init__(
    self,
    header: BlockHeader,
    body: BlockBody
  ) -> None:
    self.header: BlockHeader = header
    self.body: BlockBody = body

  #Mine.
  def mine(
    self,
    privKey: PrivateKey,
    difficulty: int
  ) -> None:
    self.header.mine(privKey, difficulty)

  #Serialize.
  def serialize(
    self
  ) -> bytes:
    return self.header.serialize() + self.body.serialize(self.header.sketchSalt)

  #Block -> JSON.
  def toJSON(
    self
  ) -> Dict[str, Any]:
    result: Dict[str, Any] = self.body.toJSON()
    result["header"] = self.header.toJSON()
    result["hash"] = self.header.hash.hex().upper()
    return result

  #JSON -> Block.
  @staticmethod
  def fromJSON(
    json: Dict[str, Any]
  ) -> Any:
    return Block(
      BlockHeader.fromJSON(json["header"]),
      BlockBody.fromJSON(json)
    )
