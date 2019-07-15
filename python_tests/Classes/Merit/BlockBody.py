#List type.
from typing import List, Tuple

#BLS lib.
from blspy import PrivateKey, PublicKey

#BlockBody class.
class BlockBody:
    #Constructor.
    def __init__(
        self,
        records: List[None] = [],
        miners: List[Tuple[PublicKey, int]] = [
            (PrivateKey.from_seed(b"").get_public_key(), 100)
        ]
    ) -> None:
        self.records = []
        self.miners = miners

    #Get the serialized miners.
    def getSerializedMiners(
        self
    ) -> List[bytes]:
        result = []
        for miner in self.miners:
            result.append(miner[0].serialize() + miner[1].to_bytes(1, byteorder="big"))
        return result

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        result = (
            len(self.records).to_bytes(4, byteorder="big") +
            len(self.miners).to_bytes(1, byteorder="big") +
            bytes().join(self.getSerializedMiners())
        )
        return result
