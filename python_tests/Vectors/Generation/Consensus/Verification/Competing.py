#Types.
from typing import IO, Dict, Any

#Transactions classes.
from python_tests.Classes.Transactions.Claim import Claim
from python_tests.Classes.Transactions.Send import Send
from python_tests.Classes.Transactions.Transactions import Transactions

#Consensus classes.
from python_tests.Classes.Consensus.Verification import Verification, SignedVerification
from python_tests.Classes.Consensus.Consensus import Consensus

#Blockchain classes.
from python_tests.Classes.Merit.BlockHeader import BlockHeader
from python_tests.Classes.Merit.BlockBody import BlockBody
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Merit import Blockchain

#Ed25519 lib.
import ed25519

#BLS lib.
import blspy

#Time standard function.
from time import time

#JSON standard lib.
import json

cmFile: IO[Any] = open("python_tests/Vectors/Transactions/ClaimedMint.json", "r")
cmVectors: Dict[str, Any] = json.loads(cmFile.read())
#Transactions.
transactions: Transactions = Transactions.fromJSON(
    cmVectors["transactions"]
)
#Consensus.
consensus: Consensus = Consensus.fromJSON(
    bytes.fromhex("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
    bytes.fromhex("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"),
    cmVectors["consensus"]
)
#Blockchain.
blockchain: Blockchain = Blockchain.fromJSON(
    b"MEROS_DEVELOPER_NETWORK",
    60,
    int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
    cmVectors["blockchain"]
)
cmFile.close()

#Ed25519 keys.
edPrivKey1: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey1: ed25519.VerifyingKey = edPrivKey1.get_verifying_key()
edPubKey2: ed25519.VerifyingKey = ed25519.SigningKey(b'\1' * 32).get_verifying_key()

#BLS keys.
blsPrivKey1: blspy.PrivateKey = blspy.PrivateKey.from_seed(b'\0')
blsPubKey1: blspy.PublicKey = blsPrivKey1.get_public_key()
blsPrivKey2: blspy.PrivateKey = blspy.PrivateKey.from_seed(b'\1')
blsPubKey2: blspy.PublicKey = blsPrivKey2.get_public_key()

#Grab the claim hash.
claim: bytes = Verification.fromElement(consensus.holders[blsPubKey1.serialize()][1]).hash

#Create two competing Sends.
send1: Send = Send(
    [(
        claim,
        0
    )],
    [(
        edPubKey1.to_bytes(),
        Claim.fromTransaction(transactions.txs[claim]).amount
    )]
)
send1.sign(edPrivKey1)
send1.beat(consensus.sendFilter)
send1.verified = True
transactions.add(send1)

send2: Send = Send(
    [(
        claim,
        0
    )],
    [(
        edPubKey2.to_bytes(),
        Claim.fromTransaction(transactions.txs[claim]).amount
    )]
)
send2.sign(edPrivKey1)
send2.beat(consensus.sendFilter)
transactions.add(send2)

#Give the second key pair Merit.
block: Block = Block(
    BlockHeader(
        21,
        blockchain.last(),
        int(time())
    ),
    BlockBody(
        [],
        [(blsPubKey2, 100)]
    )
)
block.mine(blockchain.difficulty)
blockchain.add(block)
print("Generated Competing Block " + str(block.header.nonce) + ".")

#Verify the 1st Send with the 1st key.
verif = SignedVerification(send1.hash)
verif.sign(blsPrivKey1, len(consensus.holders[blsPubKey1.serialize()]))
consensus.add(verif)

#Verify the 2nd Send with the 2nd key.
verif = SignedVerification(send2.hash)
verif.sign(blsPrivKey2, 0)
consensus.add(verif)

#Archive the Elements.
block = Block(
    BlockHeader(
        22,
        blockchain.last(),
        int(time()),
        consensus.getAggregate(
            [
                (blsPubKey1, 2, -1),
                (blsPubKey2, 0, -1)
            ]
        )
    ),
    BlockBody([
        (
            blsPubKey1,
            2,
            consensus.getMerkle(blsPubKey1, 2)
        ),
        (
            blsPubKey2,
            0,
            consensus.getMerkle(blsPubKey2, 0)
        )
    ])
)
block.mine(blockchain.difficulty)
blockchain.add(block)
print("Generated Competing Block " + str(block.header.nonce) + ".")

#Save the appended data (3 Blocks and 12 Sends).
result: Dict[str, Any] = {
    "blockchain": blockchain.toJSON(),
    "transactions": transactions.toJSON(),
    "consensus":  consensus.toJSON()
}
vectors: IO[Any] = open("python_tests/Vectors/Consensus/Verification/Competing.json", "w")
vectors.write(json.dumps(result))
vectors.close()
