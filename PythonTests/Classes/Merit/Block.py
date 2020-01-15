#Types.
from typing import Dict, List, Any

#RandomX lib.
from PythonTests.Libs.RandomX import RandomX

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey

#BlockHeader and BlockBody classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody

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
        self.header.proof = -1
        while (
            (self.header.proof == -1) or
            (int.from_bytes(self.header.hash, "big") < difficulty)
        ):
            self.header.proof += 1
            self.header.hash = RandomX(self.header.serializeHash())
            self.header.signature = privKey.sign(self.header.hash).serialize()

            self.header.hash = RandomX(self.header.hash + self.header.signature)

    #Serialize.
    def serialize(
        self,
        lookup: List[bytes]
    ) -> bytes:
        return self.header.serialize() + self.body.serialize(lookup, self.header.sketchSalt)

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
        keys: Dict[bytes, int],
        json: Dict[str, Any]
    ) -> Any:
        return Block(
            BlockHeader.fromJSON(json["header"]),
            BlockBody.fromJSON(keys, json)
        )
