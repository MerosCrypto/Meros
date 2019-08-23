#Types.
from typing import IO, Dict, List, Any

#Data class.
from python_tests.Classes.Transactions.Data import Data

#Consensus classes.
from python_tests.Classes.Consensus.Verification import SignedVerification
from python_tests.Classes.Consensus.Consensus import Consensus

#Blockchain classes.
from python_tests.Classes.Merit.BlockHeader import BlockHeader
from python_tests.Classes.Merit.BlockBody import BlockBody
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Blockchain import Blockchain

#BLS lib.
import blspy

#Time standard function.
from time import time

#Ed25519 lib.
import ed25519

#JSON standard lib.
import json

#Consensus.
consensus: Consensus = Consensus(
    bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
    bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"),
)
#Blockchain.
blockchain: Blockchain = Blockchain(
    b"MEROS_DEVELOPER_NETWORK",
    60,
    int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16)
)

#Ed25519 keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#BLS Keys.
privKey: blspy.PrivateKey = blspy.PrivateKey.from_seed(b'\0')
pubKey: blspy.PublicKey = privKey.get_public_key()

#Add a single Block to create Merit.
bbFile: IO[Any] = open("python_tests/Vectors/Merit/BlankBlocks.json", "r")
blocks: List[Dict[str, Any]] = json.loads(bbFile.read())
blockchain.add(Block.fromJSON(blocks[0]))
bbFile.close()

#Create a Data with an invalid signature.
data: Data = Data(
    edPubKey.to_bytes().rjust(48, b'\0'),
    bytes()
)
data.signature = edPrivKey.sign(b"INVALID")
data.beat(consensus.dataFilter)

#Create a Verification.
sv: SignedVerification = SignedVerification(data.hash)
sv.sign(privKey, 0)
consensus.add(sv)

#Generate another Block.
block: Block = Block(
    BlockHeader(
        2,
        blockchain.last(),
        int(time()),
        consensus.getAggregate(
            [(pubKey, 0, -1)]
        )
    ),
    BlockBody([
        (
            pubKey,
            0,
            consensus.getMerkle(
                pubKey,
                0
            )
        )
    ])
)
#Mine it.
block.mine(blockchain.difficulty)

#Add it.
blockchain.add(block)
print("Generated Parsable Block " + str(block.header.nonce) + ".")

result: Dict[str, Any] = {
    "blockchain":   blockchain.toJSON(),
    "data":         data.toJSON(),
    "verification": sv.toSignedJSON()
}
vectors: IO[Any] = open("python_tests/Vectors/Consensus/Verification/Parsable.json", "w")
vectors.write(json.dumps(result))
vectors.close()
