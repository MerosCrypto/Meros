#Types.
from typing import IO, Dict, Any

#Consensus classes.
from PythonTests.Classes.Consensus.Element import SignedElement
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.MeritRemoval import SignedMeritRemoval
from PythonTests.Classes.Consensus.Consensus import Consensus

#Blockchain classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain

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

#BLS Keys.
privKey: blspy.PrivateKey = blspy.PrivateKey.from_seed(b'\0')
pubKey: blspy.PublicKey = privKey.get_public_key()

#Load a Multiple Block and load their MeritRemoval.
snFile: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/SameNonce.json", "r")
snVectors: Dict[str, Any] = json.loads(snFile.read())

blockchain.add(Block.fromJSON(snVectors["blockchain"][0]))

mr1: SignedMeritRemoval = SignedMeritRemoval.fromJSON(snVectors["removal"])

snFile.close()

#Create a second MeritRemoval.
sv: SignedVerification = SignedVerification(b'\1' * 48)
sv.sign(privKey, 0)
mr2: SignedMeritRemoval = SignedMeritRemoval(
    mr1.se1,
    SignedElement.fromElement(sv)
)

#Add the second MeritRemoval to Consensus.
consensus.add(mr2)

#Generate a Block with the second MeritRemoval.
block: Block = Block(
    BlockHeader(
        2,
        blockchain.last(),
        int(time()),
        consensus.getAggregate([(pubKey, 0, -1)])
    ),
    BlockBody([(pubKey, 0, consensus.getMerkle(pubKey, 0))])
)
#Mine it.
block.mine(blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated Multiple Block " + str(block.header.nonce) + ".")

result: Dict[str, Any] = {
    "blockchain": blockchain.toJSON(),
    "data":       snVectors["data"],
    "removal1":   mr1.toSignedJSON(),
    "removal2":   mr2.toSignedJSON()
}
vectors: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/Multiple.json", "w")
vectors.write(json.dumps(result))
vectors.close()
