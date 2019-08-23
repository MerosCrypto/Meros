#Types.
from typing import IO, Dict, List, Any

#Data class.
from python_tests.Classes.Transactions.Data import Data

#Consensus classes.
from python_tests.Classes.Consensus.Element import SignedElement
from python_tests.Classes.Consensus.Verification import SignedVerification
from python_tests.Classes.Consensus.MeritRemoval import SignedMeritRemoval
from python_tests.Classes.Consensus.Consensus import Consensus

#Blockchain classes.
from python_tests.Classes.Merit.BlockHeader import BlockHeader
from python_tests.Classes.Merit.BlockBody import BlockBody
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Blockchain import Blockchain

#BLS lib.
import blspy

#Ed25519 lib.
import ed25519

#Time standard function.
from time import time

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

#BLS Keys.
privKey: blspy.PrivateKey = blspy.PrivateKey.from_seed(b'\0')
pubKey: blspy.PublicKey = privKey.get_public_key()

#Ed25519 keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#Add a single Block to create Merit.
bbFile: IO[Any] = open("python_tests/Vectors/Merit/BlankBlocks.json", "r")
blocks: List[Dict[str, Any]] = json.loads(bbFile.read())
blockchain.add(Block.fromJSON(blocks[0]))
bbFile.close()

#Create a Data to verify.
data: Data = Data(
    edPubKey.to_bytes().rjust(48, b'\0'),
    bytes()
)
data.sign(edPrivKey)
data.beat(consensus.dataFilter)

#Create two Verifications with the same nonce, yet for the different Datas.
sv1: SignedVerification = SignedVerification(data.hash)
sv1.sign(privKey, 0)

sv2: SignedVerification = SignedVerification(b'\0' * 48)
sv2.sign(privKey, 0)

removal: SignedMeritRemoval = SignedMeritRemoval(
    SignedElement.fromElement(sv1),
    SignedElement.fromElement(sv2)
)
consensus.add(removal)

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
print("Generated Same Nonce Block " + str(block.header.nonce) + ".")

result: Dict[str, Any] = {
    "blockchain": blockchain.toJSON(),
    "data":       data.toJSON(),
    "removal":    removal.toSignedJSON()
}
vectors: IO[Any] = open("python_tests/Vectors/Consensus/MeritRemoval/SameNonce.json", "w")
vectors.write(json.dumps(result))
vectors.close()
