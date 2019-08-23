#Types.
from typing import Dict, Any

#BlockHeader and BlockBody classes.
from python_tests.Classes.Merit.BlockHeader import BlockHeader
from python_tests.Classes.Merit.BlockBody import BlockBody

#Blake2b standard function.
from hashlib import blake2b

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
        if self.header.nonce != 0:
            self.header.setMiners(
                blake2b(
                    self.body.getSerializedMiners()[0],
                    digest_size = 48
                ).digest()
            )

    #Mine.
    def mine(
        self,
        difficulty: int
    ) -> None:
        self.header.rehash()
        while int.from_bytes(self.header.hash, "big") < difficulty:
            self.header.proof += 1
            self.header.rehash()

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        return (
            self.header.serialize() +
            self.body.serialize()
        )

    #Block -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = self.body.toJSON()
        result["header"] = self.header.toJSON()
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
