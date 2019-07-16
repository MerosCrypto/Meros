# pyright: strict

#Types.
from typing import Dict, List, Tuple, Any

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
        self.records: List[None] = []
        self.miners: List[Tuple[PublicKey, int]] = miners

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

    #Convert to JSON.
    def json(
        self
    ) -> Dict[str, Any]:
        result = {
            "records": self.records,
            "miners": []
        }
        for miner in self.miners:
            result["miners"].append((miner[0].serialize().hex(), miner[1]))

        return result
