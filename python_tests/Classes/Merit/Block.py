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
        self.header = header
        self.body = body
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
