#Types.
from typing import Dict, List, IO, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, PublicKey, Signature

#Data class.
from PythonTests.Classes.Transactions.Data import Data

#Element classes.
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.VerificationPacket import SignedVerificationPacket, SignedMeritRemovalVerificationPacket
from PythonTests.Classes.Consensus.MeritRemoval import SignedMeritRemoval

#SpamFilter class.
from PythonTests.Classes.Consensus.SpamFilter import SpamFilter

#Blockchain classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Ed25519 lib.
import ed25519

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#Ed25519 Keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#BLS Keys.
blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#SpamFilter.
spamFilter: SpamFilter = SpamFilter(bytes.fromhex("CC" * 32))

#Blockchains.
packetedChain: Blockchain = Blockchain()
reorderedChain: Blockchain = Blockchain()

#Generate a Block granting the holder Merit.
block = Block(
    BlockHeader(
        0,
        packetedChain.last(),
        bytes(32),
        1,
        bytes(4),
        bytes(32),
        blsPubKey.serialize(),
        packetedChain.blocks[-1].header.time + 1200
    ),
    BlockBody()
)
#Mine it.
block.mine(blsPrivKey, packetedChain.difficulty())

#Add it.
packetedChain.add(block)
reorderedChain.add(block)
print("Generated Hundred Twenty Three Packet Block 1/2 " + str(len(packetedChain.blocks)) + ".")

#Create the initial Data and two competing Datas.
datas: List[Data] = [Data(bytes(32), edPubKey.to_bytes())]
datas.append(Data(datas[0].hash, b"Initial Data."))
datas.append(Data(datas[0].hash, b"Second Data."))
for data in datas:
    data.sign(edPrivKey)
    data.beat(spamFilter)

#Create Verifications for all 3.
verifs: List[SignedVerification] = []
for data in datas:
    verifs.append(SignedVerification(data.hash, 0))
    verifs[-1].sign(0, blsPrivKey)

#Create a MeritRemoval out of the conflicting Verifications.
mr: SignedMeritRemoval = SignedMeritRemoval(verifs[1], verifs[2])

#Generate a Block containing the MeritRemoval.
block = Block(
    BlockHeader(
        0,
        packetedChain.last(),
        BlockHeader.createContents([], [mr]),
        1,
        bytes(4),
        bytes(32),
        0,
        packetedChain.blocks[-1].header.time + 1200
    ),
    BlockBody([], [mr], mr.signature)
)
#Mine it.
block.mine(blsPrivKey, packetedChain.difficulty())

#Add it.
packetedChain.add(block)
print("Generated Hundred Twenty Three Packet Block 1 " + str(len(packetedChain.blocks)) + ".")

#Create a MeritRemoval with random keys.
packeted: SignedMeritRemoval = SignedMeritRemoval(
    SignedMeritRemovalVerificationPacket(
        SignedVerificationPacket(verifs[1].hash),
        [
            blsPubKey.serialize(),
            PrivateKey(blake2b(b'\1', digest_size=32).digest()).toPublicKey().serialize(),
            PrivateKey(blake2b(b'\2', digest_size=32).digest()).toPublicKey().serialize()
        ],
        Signature.aggregate([
            blsPrivKey.sign(verifs[1].signatureSerialize()),
            PrivateKey(blake2b(b'\1', digest_size=32).digest()).sign(verifs[1].signatureSerialize()),
            PrivateKey(blake2b(b'\2', digest_size=32).digest()).sign(verifs[1].signatureSerialize())
        ])
    ),
    SignedMeritRemovalVerificationPacket(
        SignedVerificationPacket(verifs[2].hash),
        [
            blsPubKey.serialize(),
            PrivateKey(blake2b(b'\3', digest_size=32).digest()).toPublicKey().serialize(),
            PrivateKey(blake2b(b'\4', digest_size=32).digest()).toPublicKey().serialize()
        ],
        Signature.aggregate(
            [
                blsPrivKey.sign(verifs[2].signatureSerialize()),
                PrivateKey(blake2b(b'\3', digest_size=32).digest()).sign(verifs[2].signatureSerialize()),
                PrivateKey(blake2b(b'\4', digest_size=32).digest()).sign(verifs[2].signatureSerialize())
            ]
        )
    ),
    0
)

#Generate a Block containing the repeat MeritRemoval.
block = Block(
    BlockHeader(
        0,
        packetedChain.last(),
        BlockHeader.createContents([], [packeted]),
        1,
        bytes(4),
        bytes(32),
        0,
        packetedChain.blocks[-1].header.time + 1200
    ),
    BlockBody([], [packeted], packeted.signature)
)
#Mine it.
block.mine(blsPrivKey, packetedChain.difficulty())

#Add it.
packetedChain.add(block)
print("Generated Hundred Twenty Three Packet Block 1 " + str(len(packetedChain.blocks)) + ".")

#Generate a Block containing the packeted MeritRemoval.
block = Block(
    BlockHeader(
        0,
        reorderedChain.last(),
        BlockHeader.createContents([], [packeted]),
        1,
        bytes(4),
        bytes(32),
        0,
        reorderedChain.blocks[-1].header.time + 1200
    ),
    BlockBody([], [packeted], packeted.signature)
)
#Mine it.
block.mine(blsPrivKey, reorderedChain.difficulty())

#Add it.
reorderedChain.add(block)
print("Generated Hundred Twenty Three Packet Block 2 " + str(len(reorderedChain.blocks)) + ".")

#Recreate the MeritRemoval with reordered keys.
reordered: SignedMeritRemoval = SignedMeritRemoval(
    SignedMeritRemovalVerificationPacket(
        SignedVerificationPacket(verifs[1].hash),
        [
            blsPubKey.serialize(),
            PrivateKey(blake2b(b'\1', digest_size=32).digest()).toPublicKey().serialize(),
            PrivateKey(blake2b(b'\2', digest_size=32).digest()).toPublicKey().serialize()
        ],
        Signature.aggregate(
            [
                blsPrivKey.sign(verifs[1].signatureSerialize()),
                PrivateKey(blake2b(b'\1', digest_size=32).digest()).sign(verifs[1].signatureSerialize()),
                PrivateKey(blake2b(b'\2', digest_size=32).digest()).sign(verifs[1].signatureSerialize())
            ]
        )
    ),
    SignedMeritRemovalVerificationPacket(
        SignedVerificationPacket(verifs[2].hash),
        [
            PrivateKey(blake2b(b'\3', digest_size=32).digest()).toPublicKey().serialize(),
            blsPubKey.serialize(),
            PrivateKey(blake2b(b'\4', digest_size=32).digest()).toPublicKey().serialize()
        ],
        Signature.aggregate(
            [
                blsPrivKey.sign(verifs[2].signatureSerialize()),
                PrivateKey(blake2b(b'\3', digest_size=32).digest()).sign(verifs[2].signatureSerialize()),
                PrivateKey(blake2b(b'\4', digest_size=32).digest()).sign(verifs[2].signatureSerialize())
            ]
        )
    ),
    0
)

#Generate a Block containing the reordered MeritRemoval.
block = Block(
    BlockHeader(
        0,
        reorderedChain.last(),
        BlockHeader.createContents([], [reordered]),
        1,
        bytes(4),
        bytes(32),
        0,
        reorderedChain.blocks[-1].header.time + 1200
    ),
    BlockBody([], [reordered], reordered.signature)
)
#Mine it.
block.mine(blsPrivKey, reorderedChain.difficulty())

#Add it.
reorderedChain.add(block)
print("Generated Hundred Twenty Three Packet Block 2 " + str(len(reorderedChain.blocks)) + ".")

result: Dict[str, Any] = {
    "blockchains": [packetedChain.toJSON(), reorderedChain.toJSON()],
    "datas": [datas[0].toJSON(), datas[1].toJSON(), datas[2].toJSON()],
    "removals": [mr.toSignedJSON(), packeted.toSignedJSON()]
}
vectors: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/HundredTwentyThree/Packet.json", "w")
vectors.write(json.dumps(result))
vectors.close()
