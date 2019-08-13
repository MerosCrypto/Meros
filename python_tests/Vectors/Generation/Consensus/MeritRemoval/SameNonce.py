#Types.
from typing import IO, Dict, List, Any

#Transactions class.
from python_tests.Classes.Transactions.Transactions import Transactions

#Consensus classes.
from python_tests.Classes.Consensus.Element import SignedElement
from python_tests.Classes.Consensus.Verification import SignedVerification
from python_tests.Classes.Consensus.MeritRemoval import SignedMeritRemoval
from python_tests.Classes.Consensus.Consensus import Consensus

#Merit classes.
from python_tests.Classes.Merit.BlockHeader import BlockHeader
from python_tests.Classes.Merit.BlockBody import BlockBody
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Merit import Merit

#BLS lib.
import blspy

#Time standard function.
from time import time

#JSON standard lib.
import json

#Transactionss.
transactions: Transactions = Transactions()
#Consensus.
consensus: Consensus = Consensus(
    bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
    bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"),
)
#Merit.
merit: Merit = Merit(
    b"MEROS_DEVELOPER_NETWORK",
    60,
    int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
    100
)

#BLS Keys.
privKey: blspy.PrivateKey = blspy.PrivateKey.from_seed(b'\0')
pubKey: blspy.PublicKey = privKey.get_public_key()

#Add a single Block to create Merit.
bbFile: IO[Any] = open("python_tests/Vectors/Merit/BlankBlocks.json", "r")
blocks: List[Dict[str, Any]] = json.loads(bbFile.read())
merit.add(
    transactions,
    consensus,
    Block.fromJSON(blocks[0])
)
bbFile.close()

#Create two Verifications with the same nonce yet for different hashes.
h1: bytes = b'\0' * 48
sv1: SignedVerification = SignedVerification(h1)
sv1.sign(privKey, 0)

h2: bytes = b'\1' * 48
sv2: SignedVerification = SignedVerification(h2)
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
        merit.blockchain.last(),
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
block.header.rehash()
while int.from_bytes(block.header.hash, "big") < merit.blockchain.difficulty:
    block.header.proof += 1
    block.header.rehash()

#Add it.
merit.add(transactions, consensus, block)
print("Generated Same Nonce Block " + str(block.header.nonce) + ".")

result: Dict[str, Any] = {
    "blockchain": merit.blockchain.toJSON(),
    "removal":    removal.toSignedJSON()
}
vectors: IO[Any] = open("python_tests/Vectors/Consensus/MeritRemoval/SameNonce.json", "w")
vectors.write(json.dumps(result))
vectors.close()
