#Types.
from typing import Dict, List, Tuple, Any

#BLS lib.
import blspy

#BlockBody class.
class BlockBody:
    #Constructor.
    def __init__(
        self,
        records: List[Tuple[blspy.PublicKey, int, bytes]] = [],
        miners: List[Tuple[blspy.PublicKey, int]] = [
            (blspy.PrivateKey.from_seed(b'\0').get_public_key(), 100)
        ]
    ) -> None:
        self.records: List[Tuple[blspy.PublicKey, int, bytes]] = records
        self.miners: List[Tuple[blspy.PublicKey, int]] = miners

    #Get the serialized miners.
    def getSerializedMiners(
        self
    ) -> List[bytes]:
        result: List[bytes] = []
        for miner in self.miners:
            result.append(miner[0].serialize() + miner[1].to_bytes(1, byteorder = "big"))
        return result

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        result: bytes = len(self.records).to_bytes(4, byteorder = "big")
        for record in self.records:
            result += (
                record[0].serialize() +
                record[1].to_bytes(4, byteorder = "big") +
                record[2]
            )

        result += (
            len(self.miners).to_bytes(1, byteorder = "big") +
            bytes().join(self.getSerializedMiners())
        )

        return result

    #BlockBody -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "records": [],
            "miners": []
        }
        for record in self.records:
            result["records"].append({
                "holder": record[0].serialize().hex().upper(),
                "nonce": record[1],
                "merkle": record[2].hex().upper()
            })
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
        records: List[Tuple[blspy.PublicKey, int, bytes]] = []
        miners: List[Tuple[blspy.PublicKey, int]] = []
        for record in json["records"]:
            records.append((
                blspy.PublicKey.from_bytes(bytes.fromhex(record["holder"])),
                record["nonce"],
                bytes.fromhex(record["merkle"])
            ))
        for miner in json["miners"]:
            miners.append((
                blspy.PublicKey.from_bytes(bytes.fromhex(miner["miner"])),
                miner["amount"]
            ))

        return BlockBody(
            records,
            miners
        )
