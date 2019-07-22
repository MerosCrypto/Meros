#Types.
from typing import Dict, Any

#Argon2 lib.
import argon2

#BlockHeader class.
class BlockHeader:
    #Serialize.
    def serialize(
        self
    ) -> bytes:
        return (
            self.nonce.to_bytes(4, byteorder = "big") +
            self.last +
            self.aggregate +
            self.miners +
            self.time.to_bytes(4, byteorder = "big") +
            self.proof.to_bytes(4, byteorder = "big")
        )

    #Hash.
    def rehash(
        self
    ) -> None:
        self.hash: bytes = argon2.low_level.hash_secret_raw(
            self.serialize()[0 : 200],
            self.serialize()[200 : 204].rjust(8, b'\0'),
            1,
            131072,
            1,
            48,
            argon2.low_level.Type.D
        )

    #Constructor.
    def __init__(
        self,
        nonce: int,
        last: bytes,
        time: int,
        aggregate: bytes = bytes(96),
        miners: bytes = bytes(48),
        proof: int = 0
    ) -> None:
        self.nonce: int = nonce
        self.last: bytes = last
        self.time: int = time
        self.aggregate: bytes = aggregate
        self.miners: bytes = miners
        self.proof: int = proof

        self.rehash()

    #Set aggregate.
    def setAggregate(
        self,
        aggregate: bytes
    ) -> None:
        self.aggregate = aggregate

    #Set miners.
    def setMiners(
        self,
        miners: bytes
     )-> None:
        self.miners = miners

    #BlockHeader -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "nonce": self.nonce,
            "last": self.last.hex().upper(),
            "aggregate": self.aggregate.hex().upper(),
            "miners": self.miners.hex().upper(),
            "time": self.time,
            "proof": self.proof,
            "hash": self.hash.hex().upper()
        }

    #JSON -> BlockHeader.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return BlockHeader(
            json["nonce"],
            bytes.fromhex(json["last"]),
            json["time"],
            bytes.fromhex(json["aggregate"]),
            bytes.fromhex(json["miners"]),
            json["proof"]
        )
