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
blockchain: Blockchain = Blockchain()

#Generate a Block granting the holder Merit.
block = Block(
    BlockHeader(
        0,
        blockchain.last(),
        bytes(32),
        1,
        bytes(4),
        bytes(32),
        blsPubKey.serialize(),
        blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody()
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated Hundred Thirty Five Block " + str(len(blockchain.blocks)) + ".")

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

#Generate a Block containing the modified MeritRemoval.
block = Block(
    BlockHeader(
        0,
        blockchain.last(),
        BlockHeader.createContents([], [packeted]),
        1,
        bytes(4),
        bytes(32),
        0,
        blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody([], [packeted], packeted.signature)
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated Hundred Thirty Five Block " + str(len(blockchain.blocks)) + ".")

result: Dict[str, Any] = {
    "blockchain": blockchain.toJSON(),
    "datas": [datas[0].toJSON(), datas[1].toJSON(), datas[2].toJSON()],
    "removal": mr.toSignedJSON()
}
vectors: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/HundredThirtyFive.json", "w")
vectors.write(json.dumps(result))
vectors.close()
