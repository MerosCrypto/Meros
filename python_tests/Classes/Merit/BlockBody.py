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
        result: List[bytes] = []
        for miner in self.miners:
            result.append(miner[0].serialize() + miner[1].to_bytes(1, byteorder="big"))
        return result

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        result: bytes = (
            len(self.records).to_bytes(4, byteorder="big") +
            len(self.miners).to_bytes(1, byteorder="big") +
            bytes().join(self.getSerializedMiners())
        )
        return result

    #BlockBody -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "records": self.records,
            "miners": []
        }
        for miner in self.miners:
            result["miners"].append({
                "miner": miner[0].serialize().hex().upper(),
                "amount": miner[1]
            })

        return result

    #JSON -> Blockbody.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        miners: List[Tuple[PublicKey, int]] = []
        for miner in json["miners"]:
            miners.append((
                PublicKey.from_bytes(bytes.fromhex(miner["miner"])),
                miner["amount"]
            ))

        return BlockBody(
            json["records"],
            miners
        )
