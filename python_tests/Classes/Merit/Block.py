# pyright: strict

#Types.
from typing import Dict, Any

#BlockHeader and BlockBody libs.
from python_tests.Classes.Merit.BlockHeader import BlockHeader
from python_tests.Classes.Merit.BlockBody import BlockBody

#Blake2b.
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

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        return (
            self.header.serialize() +
            self.body.serialize()
        )

    #Convert to JSON.
    def json(
        self
    ) -> Dict[str, Any]:
        result = self.body.json()
        result["header"] = self.header.json()
        return result
