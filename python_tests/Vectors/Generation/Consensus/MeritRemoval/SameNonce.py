#Types.
from typing import IO, Dict, List, Any

#Merit classes.
from python_tests.Classes.Merit.BlockHeader import BlockHeader
from python_tests.Classes.Merit.BlockBody import BlockBody
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Merit import Merit

#Transactions class.
from python_tests.Classes.Transactions.Transactions import Transactions

#Consensus classes.
from python_tests.Classes.Consensus.Element import SignedElement
from python_tests.Classes.Consensus.Verification import SignedVerification
from python_tests.Classes.Consensus.MeritRemoval import SignedMeritRemoval
from python_tests.Classes.Consensus.Consensus import Consensus

#BLS lib.
import blspy

#Time standard function.
from time import time

#JSON standard lib.
import json

#Transactions.
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

#BLS keys.
blsPrivKey: blspy.PrivateKey = blspy.PrivateKey.from_seed(b'\0')
blsPubKey: blspy.PublicKey = blsPrivKey.get_public_key()

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
svs: List[SignedVerification] = []
for i in range(0, 2):
    h: bytes = i.to_bytes(1, byteorder = "big") * 48
    svs.append(SignedVerification(h))
    svs[-1].sign(blspy.PrivateKey.from_seed(b'\0'), 0)
consensus.add(SignedMeritRemoval(
    0,
    SignedElement.fromElement(svs[0]),
    SignedElement.fromElement(svs[1])
))

#Generate another Block.
block: Block = Block(
    BlockHeader(
        2,
        merit.blockchain.last(),
        int(time()),
        consensus.getAggregate(
            [(blsPubKey, 0)]
        )
    ),
    BlockBody([
        (
            blsPubKey,
            0,
            consensus.getMerkle(
                blsPubKey,
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
    "consensus":  consensus.toJSON()
}
vectors: IO[Any] = open("python_tests/Vectors/Consensus/MeritRemoval/SameNonce.json", "w")
vectors.write(json.dumps(result))
vectors.close()
