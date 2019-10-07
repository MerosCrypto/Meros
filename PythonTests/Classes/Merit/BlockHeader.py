#Types.
from typing import Dict, Union, Any

#Argon2 lib.
import argon2

#BlockHeader class.
#pylint: disable=too-many-instance-attributes
class BlockHeader:
    #Serialize to be hashed.
    def serializeHash(
        self
    ) -> bytes:
        return (
            self.version.to_bytes(4, "big") +
            self.last +
            self.contents +
            self.verifiers +
            (1 if self.newMiner else 0).to_bytes(1, 'big') +
            (self.minerKey if self.newMiner else self.minerNick.to_bytes(2, "big")) +
            self.time.to_bytes(4, "big")
        )

    #Hash.
    def rehash(
        self
    ) -> None:
        self.hash: bytes = argon2.low_level.hash_secret_raw(
            argon2.low_level.hash_secret_raw(
                self.serializeHash(),
                self.proof.to_bytes(8, "big"),
                1,
                65536,
                1,
                48,
                argon2.low_level.Type.D
            ),
            self.signature,
            1,
            65536,
            1,
            48,
            argon2.low_level.Type.D
        )

    #Constructor.
    def __init__(
        self,
        version: int,
        last: bytes,
        contents: bytes,
        verifiers: bytes,
        miner: Union[int, bytes],
        time: int,
        proof: int = 0,
        signature: bytes = bytes(96)
    ) -> None:
        self.version: int = version
        self.last: bytes = last
        self.contents: bytes = contents
        self.verifiers: bytes = verifiers
        self.newMiner: bool = isinstance(miner, bytes)
        if isinstance(miner, bytes):
            self.minerKey: bytes = miner
        else:
            self.minerNick: int = miner
        self.time: int = time
        self.proof: int = proof
        self.signature: bytes = signature

        self.rehash()

    #Serialize.
    def serialize(
        self
    ) -> bytes:
        return (
            self.serializeHash() +
            self.proof.to_bytes(4, "big") +
            self.signature
        )

    #BlockHeader -> JSON.
    def toJSON(
        self
    ) -> Dict[str, Any]:
        return {
            "version": self.version,
            "last": self.last.hex().upper(),
            "contents": self.contents.hex().upper(),
            "verifiers": self.verifiers.hex().upper(),
            "miner": self.minerKey.hex().upper() if self.newMiner else self.minerNick,
            "time": self.time,
            "proof": self.proof,
            "signature": self.signature.hex().upper()
        }

    #JSON -> BlockHeader.
    @staticmethod
    def fromJSON(
        json: Dict[str, Any]
    ) -> Any:
        return BlockHeader(
            json["version"],
            bytes.fromhex(json["last"]),
            bytes.fromhex(json["contents"]),
            bytes.fromhex(json["verifiers"]),
            bytes.fromhex(json["miner"]) if isinstance(json["miner"], str) else json["miner"],
            json["time"],
            json["proof"],
            bytes.fromhex(json["signature"])
        )
