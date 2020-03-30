#Types.
from typing import IO, Dict, List, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, PublicKey, Signature

#Data class.
from PythonTests.Classes.Transactions.Data import Data

#SpamFilter class.
from PythonTests.Classes.Consensus.SpamFilter import SpamFilter

#SignedVerification and VerificationPacket classes.
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket

#Blockchain classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Merit import Blockchain

#Ed25519 lib.
import ed25519

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#Blockchain.
blockchain: Blockchain = Blockchain()

#SpamFilter.
dataFilter: SpamFilter = SpamFilter(5)

#Ed25519 keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#BLS keys.
blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

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
print("Generated Prune Unaddable Block " + str(len(blockchain.blocks)) + ".")

#Create the original Data.
datas: List[Data] = [Data(bytes(32), edPubKey.to_bytes())]
datas[0].sign(edPrivKey)
datas[0].beat(dataFilter)

#Verify it.
verifs: List[SignedVerification] = [SignedVerification(datas[0].hash)]
verifs[0].sign(0, blsPrivKey)

#Create two competing Datas yet only verify the first.
for d in range(2):
    datas.append(Data(datas[0].hash, d.to_bytes(1, "big")))
    datas[1 + d].sign(edPrivKey)
    datas[1 + d].beat(dataFilter)

verifs.append(SignedVerification(datas[1].hash))
verifs[1].sign(0, blsPrivKey)

#Create a Data that's a descendant of the Data which will be beaten.
datas.append(Data(datas[2].hash, (2).to_bytes(1, "big")))
datas[3].sign(edPrivKey)
datas[3].beat(dataFilter)

#Create a SignedVerification for the descendant Data.
descendantVerif: SignedVerification = SignedVerification(datas[1].hash)
descendantVerif.sign(0, blsPrivKey)

#Convert the Verifications to packets.
packets: List[VerificationPacket] = [
    VerificationPacket(verifs[0].hash, [0]),
    VerificationPacket(verifs[1].hash, [0])
]

#Generate another 6 Blocks.
#Next block should have the packets.
block: Block = Block(
    BlockHeader(
        0,
        blockchain.last(),
        BlockHeader.createContents(packets),
        1,
        bytes(4),
        BlockHeader.createSketchCheck(bytes(4), packets),
        0,
        blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody(packets, [], Signature.aggregate([verifs[0].signature, verifs[1].signature]))
)
for _ in range(6):
    #Mine it.
    block.mine(blsPrivKey, blockchain.difficulty())

    #Add it.
    blockchain.add(block)
    print("Generated Prune Unaddable Block " + str(len(blockchain.blocks)) + ".")

    #Create the next Block.
    block = Block(
        BlockHeader(
            0,
            blockchain.last(),
            bytes(32),
            1,
            bytes(4),
            bytes(32),
            0,
            blockchain.blocks[-1].header.time + 1200
        ),
        BlockBody()
    )

result: Dict[str, Any] = {
    "blockchain": blockchain.toJSON(),
    "datas": [datas[0].toJSON(), datas[1].toJSON(), datas[2].toJSON(), datas[3].toJSON()],
    "verification": descendantVerif.toSignedJSON()
}
vectors: IO[Any] = open("PythonTests/Vectors/Transactions/PruneUnaddable.json", "w")
vectors.write(json.dumps(result))
vectors.close()
