#Types.
from typing import Dict, List, Union, Any

#VerificationPacket class.
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket

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
        packetsArg: List[VerificationPacket] = [],
        elements: List[None] = []
    ) -> bytes:
        #Extract the packets argument.
        packets: List[VerificationPacket] = list(packetsArg)

        #Support empty contents.
        if (packets == []) and (elements == []):
            return bytes(48)

        #Define the list.
        merkle: List[bytes] = []

        #Sort and append the Packets.
        packets.sort(key=lambda packet: packet.txHash, reverse=True)

        for packet in packets:
            merkle.append(blake2b(packet.serializeContents(), digest_size=48).digest())

        #Append Elements.

        #Pair down until there's one hash left.
        while len(merkle) > 1:
            if len(merkle) % 2 != 0:
                merkle.append(merkle[-1])
            for h in range(len(merkle) // 2):
                merkle[h] = blake2b(
                    merkle[h * 2] + merkle[(h * 2) + 1],
                    digest_size=48
                ).digest()
            merkle = merkle[0 : len(merkle) // 2]

        return merkle[0]

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
