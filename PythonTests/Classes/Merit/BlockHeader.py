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

#Merkle constructor.
def merkle(
    hashes: List[bytes]
) -> bytes:
    #Support empty merkles.
    if not hashes:
        return bytes(48)

    #Pair down until there's one hash left.
    while len(hashes) > 1:
        if len(hashes) % 2 != 0:
            hashes.append(hashes[-1])
        for h in range(len(hashes) // 2):
            hashes[h] = blake2b(
                hashes[h * 2] + hashes[(h * 2) + 1],
                digest_size=48
            ).digest()
        hashes = hashes[0 : len(hashes) // 2]

    #Return the merkle hash.
    return hashes[0]

#BlockHeader class.
#pylint: disable=too-many-instance-attributes
class BlockHeader:
    #Create a contents merkle.
    @staticmethod
    def createContents(
        packetsArg: List[VerificationPacket] = [],
        elements: List[None] = []
    ) -> bytes:
        #Sort the VerificationPackets.
        packets: List[VerificationPacket] = sorted(
            list(packetsArg),
            key=lambda packet: packet.hash,
            reverse=True
        )

        #Hash each packet.
        hashes: List[bytes] = []
        for packet in packets:
            hashes.append(blake2b(packet.prefix + packet.serialize(), digest_size=48).digest())

        #Hash each Element.
        for _ in elements:
            pass

        #Return the merkle hash.
        return merkle(hashes)

    #Create a sketchCheck merkle.
    @staticmethod
    def createSketchCheck(
        salt: bytes = bytes(4),
        packets: List[VerificationPacket] = []
    ) -> bytes:
        #Create sketch hashes for every packet.
        sketchHashes: List[int] = []
        for packet in packets:
            sketchHashes.append(Sketch.hash(salt, packet))

        #Sort the Sketch Hashes.
        sketchHashes.sort(reverse=True)

        #Hash each sketch hash to leaf length.
        leaves: List[bytes] = []
        for sketchHash in sketchHashes:
            leaves.append(blake2b(sketchHash.to_bytes(8, byteorder="big"), digest_size=48).digest())

        #Return the merkle hash.
        return merkle(leaves)

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
            self.sketchCheck +
            (1 if self.newMiner else 0).to_bytes(1, "big") +
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
        significant: int,
        sketchSalt: bytes,
        sketchCheck: bytes,
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
        self.sketchCheck: bytes = sketchCheck

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
            "sketchCheck": self.sketchCheck.hex().upper(),
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
            bytes.fromhex(json["sketchCheck"]),
            bytes.fromhex(json["miner"]) if isinstance(json["miner"], str) else json["miner"],
            json["time"],
            json["proof"],
            bytes.fromhex(json["signature"])
        )
