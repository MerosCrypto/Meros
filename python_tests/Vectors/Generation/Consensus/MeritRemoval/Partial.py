#Types.
from typing import IO, Dict, Any

#Consensus classes.
from python_tests.Classes.Consensus.Verification import SignedVerification
from python_tests.Classes.Consensus.MeritRemoval import PartiallySignedMeritRemoval
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

#BLS Public Key.
pubKey: blspy.PublicKey = blspy.PrivateKey.from_seed(b'\0').get_public_key()

#Add a single Block to create Merit and load a MeritRemoval.
snFile: IO[Any] = open("python_tests/Vectors/Consensus/MeritRemoval/SameNonce.json", "r")
vectors: Dict[str, Any] = json.loads(snFile.read())

blockchain.add(Block.fromJSON(vectors["blockchain"][0]))

consensus.add(SignedVerification.fromJSON(vectors["removal"]["elements"][0]))
removal: PartiallySignedMeritRemoval = PartiallySignedMeritRemoval.fromJSON(vectors["removal"])
removal.nonce = 1
consensus.add(removal)

snFile.close()

#Generate a Block with a verif and a Block with the removal.
for i in range(2):
    block: Block = Block(
        BlockHeader(
            i + 2,
            blockchain.last(),
            int(time()),
            consensus.getAggregate(
                [(pubKey, i, i)]
            )
        ),
        BlockBody([
            (
                pubKey,
                i,
                consensus.getMerkle(
                    pubKey,
                    i,
                    i
                )
            )
        ])
    )

    #Mine it.
    block.mine(blockchain.difficulty)

    #Add it.
    blockchain.add(block)
    print("Generated Partial Block " + str(block.header.nonce) + ".")

result: Dict[str, Any] = {
    "blockchain": blockchain.toJSON(),
    "data":       vectors["data"],
    "removal":    removal.toSignedJSON()
}
partialFile: IO[Any] = open("python_tests/Vectors/Consensus/MeritRemoval/Partial.json", "w")
partialFile.write(json.dumps(result))
partialFile.close()
