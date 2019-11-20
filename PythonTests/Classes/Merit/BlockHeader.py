#Types.
from typing import Dict, List, Union, Any

#VerificationPacket class.
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket

#Sketch class.
from PythonTests.Classes.Merit.Minisketch import Sketch

#Argon2 lib.
import argon2

#Blake2b standard function.
from hashlib import blake2b

#BlockHeader class.
#pylint: disable=too-many-instance-attributes
class BlockHeader:
    #Create a contents merkle.
    @staticmethod
    def createContents(
        salt: bytes = bytes(4),
        packets: List[VerificationPacket] = [],
        elements: List[None] = []
    ) -> bytes:
        #Support empty contents.
        if (packets == []) and (elements == []):
            return bytes(48)

        #Create sketch hashes for every packet.
        sketchInts: List[int] = []
        for packet in packets:
            sketchInts.append(Sketch.hash(salt, packet))

        #Sort the Sketch Hashes.
        sketchInts.sort(reverse=True)

        #Hash each sketch hash to leaf length.
        sketchHashes: List[bytes] = []
        for s in range(len(sketchInts)):
            sketchHashes.append(blake2b(sketchInts[s].to_bytes(8, byteorder="big"), digest_size=48).digest())

        #Pair down until there's one hash left.
        while len(sketchHashes) > 1:
            if len(sketchHashes) % 2 != 0:
                sketchHashes.append(sketchHashes[-1])
            for h in range(len(sketchHashes) // 2):
                sketchHashes[h] = blake2b(
                    sketchHashes[h * 2] + sketchHashes[(h * 2) + 1],
                    digest_size=48
                ).digest()
            sketchHashes = sketchHashes[0 : len(sketchHashes) // 2]
        if len(sketchHashes) == 0:
            sketchHashes[0] = bytes(48)

        #Append Elements.
        elementHashes: List[bytes] = [bytes(48)]

        return blake2b(sketchHashes[0] + elementHashes[0], digest_size=48).digest()

    #Serialize to be hashed.
    def serializeHash(
        self
    ) -> bytes:
        return (
            self.version.to_bytes(4, "big") +
            self.last +
            self.contents +
            self.significant.to_bytes(2, "big") +
            self.sketchSalt +
            (1 if self.newMiner else 0).to_bytes(1, "big") +
            (self.minerKey if self.newMiner else self.minerNick.to_bytes(2, "big")) +
            self.time.to_bytes(4, "big")
        )

    #Hash.
    def rehash(
        self
    ) -> None:
        self.blockHash: bytes = argon2.low_level.hash_secret_raw(
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
        significant: int,
        sketchSalt: bytes,
        miner: Union[int, bytes],
        time: int,
        proof: int = 0,
        signature: bytes = bytes(96)
    ) -> None:
        self.version: int = version
        self.last: bytes = last
        self.contents: bytes = contents

        self.significant: int = significant
        self.sketchSalt: bytes = sketchSalt

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
            "significant": self.significant,
            "sketchSalt": self.sketchSalt.hex().upper(),
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
            json["significant"],
            bytes.fromhex(json["sketchSalt"]),
            bytes.fromhex(json["miner"]) if isinstance(json["miner"], str) else json["miner"],
            json["time"],
            json["proof"],
            bytes.fromhex(json["signature"])
        )
