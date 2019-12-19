#Types.
from typing import IO, Dict, List, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, PublicKey

#Data class.
from PythonTests.Classes.Transactions.Data import Data

#SpamFilter class.
from PythonTests.Classes.Consensus.SpamFilter import SpamFilter

#Verification classes.
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket

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

#Blockchain.
blockchain: Blockchain = Blockchain(
    b"MEROS_DEVELOPER_NETWORK",
    60,
    int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16)
)

#Spam Filter.
dataFilter: SpamFilter = SpamFilter(
    bytes.fromhex(
        "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
    )
)

#Ed25519 keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#BLS Keys.
blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=48).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Add a single Block to create Merit.
bbFile: IO[Any] = open("PythonTests/Vectors/Merit/BlankBlocks.json", "r")
blocks: List[Dict[str, Any]] = json.loads(bbFile.read())
blockchain.add(Block.fromJSON(blocks[0]))
bbFile.close()

#Create a Data with an invalid signature.
data: Data = Data(edPubKey.to_bytes().rjust(48, b'\0'), bytes())
data.signature = edPrivKey.sign(b"INVALID")
data.beat(dataFilter)

#Create a Verification.
sv: SignedVerification = SignedVerification(data.hash)
sv.sign(0, blsPrivKey)

#Create packets out of the Verification.
packets: List[VerificationPacket] = [VerificationPacket(data.hash, [0])]

#Generate another Block.
block = Block(
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
    BlockBody(packets, [], sv.signature)
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated Parsable Block " + str(len(blockchain.blocks)) + ".")

result: Dict[str, Any] = {
    "blockchain": blockchain.toJSON(),
    "data":       data.toJSON()
}
vectors: IO[Any] = open("PythonTests/Vectors/Consensus/Verification/Parsable.json", "w")
vectors.write(json.dumps(result))
vectors.close()
