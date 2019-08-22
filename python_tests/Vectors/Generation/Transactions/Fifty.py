#Types.
from typing import IO, Dict, List, Any

#Transactions classes.
from python_tests.Classes.Transactions.Send import Send
from python_tests.Classes.Transactions.Claim import Claim
from python_tests.Classes.Transactions.Transactions import Transactions

#Consensus class.
from python_tests.Classes.Consensus.Verification import Verification, SignedVerification
from python_tests.Classes.Consensus.Consensus import Consensus

#Merit classes.
from python_tests.Classes.Merit.BlockHeader import BlockHeader
from python_tests.Classes.Merit.BlockBody import BlockBody
from python_tests.Classes.Merit.Block import Block
from python_tests.Classes.Merit.Merit import Merit

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
#Merit.
merit: Merit = Merit.fromJSON(
    b"MEROS_DEVELOPER_NETWORK",
    60,
    int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
    100,
    transactions,
    consensus,
    cmVectors["blockchain"]
)
cmFile.close()

#Ed25519 keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#BLS keys.
blsPrivKey1: blspy.PrivateKey = blspy.PrivateKey.from_seed(b'\0')
blsPubKey1: blspy.PublicKey = blsPrivKey1.get_public_key()

blsPrivKey2: blspy.PrivateKey = blspy.PrivateKey.from_seed(b'\1')
blsPubKey2: blspy.PublicKey = blsPrivKey2.get_public_key()

#Grab the claim hash.
claim: bytes = Verification.fromElement(consensus.holders[blsPubKey1.serialize()][1]).hash

#Create 12 Sends.
sends: List[Send] = []
sends.append(
    Send(
        [(
            claim,
            0
        )],
        [(
            edPubKey.to_bytes(),
            Claim.fromTransaction(transactions.txs[claim]).amount
        )]
    )
)
for _ in range(0, 12):
    sends[-1].sign(edPrivKey)
    sends[-1].beat(consensus.sendFilter)
    sends[-1].verified = True
    transactions.add(sends[-1])

    sends.append(
        Send(
            [(
                sends[-1].hash,
                0
            )],
            [(
                edPubKey.to_bytes(),
                sends[-1].outputs[0][1]
            )]
        )
    )

#Verify 0 and 1 in order.
order: List[int] = [
    0,
    1
]
verif: SignedVerification
for s in order:
    verif = SignedVerification(sends[s].hash)
    verif.sign(blsPrivKey1, len(consensus.holders[blsPubKey1.serialize()]))
    consensus.add(verif)

block: Block = Block(
    BlockHeader(
        21,
        merit.blockchain.last(),
        int(time()),
        consensus.getAggregate(
            [(blsPubKey1, 2, -1)]
        )
    ),
    BlockBody([
        (
            blsPubKey1,
            3,
            consensus.getMerkle(
                blsPubKey1,
                2
            )
        )
    ])
)
block.header.rehash()
while int.from_bytes(block.header.hash, "big") < merit.blockchain.difficulty:
    block.header.proof += 1
    block.header.rehash()
merit.add(transactions, consensus, block)
print("Generated Fifty Block " + str(block.header.nonce) + ".")

#Verify 3, and then 2, while giving Merit to a second Merit Holder.
order = [
    3,
    2
]
for s in order:
    verif = SignedVerification(sends[s].hash)
    verif.sign(blsPrivKey1, len(consensus.holders[blsPubKey1.serialize()]))
    consensus.add(verif)

block = Block(
    BlockHeader(
        22,
        merit.blockchain.last(),
        int(time()),
        consensus.getAggregate(
            [(blsPubKey1, 4, -1)]
        )
    ),
    BlockBody(
        [(
            blsPubKey1,
            5,
            consensus.getMerkle(
                blsPubKey1,
                4
            )
        )],
        [(blspy.PrivateKey.from_seed(b'\1').get_public_key(), 100)]
    )
)
block.header.rehash()
while int.from_bytes(block.header.hash, "big") < merit.blockchain.difficulty:
    block.header.proof += 1
    block.header.rehash()
merit.add(transactions, consensus, block)
print("Generated Fifty Block " + str(block.header.nonce) + ".")

#2nd Merit Holder:
order = [
    5,
    6,
    9,
    11
]
for i in range(0, len(order)):
    verif = SignedVerification(sends[order[i]].hash)
    verif.sign(blsPrivKey2, i)
    consensus.add(verif)

#1st Merit Holder:
order = [
    4,
    5,
    8,
    7,
    11,
    6,
    10,
    9
]
for s in order:
    verif = SignedVerification(sends[s].hash)
    verif.sign(blsPrivKey1, len(consensus.holders[blsPubKey1.serialize()]))
    consensus.add(verif)

block = Block(
    BlockHeader(
        23,
        merit.blockchain.last(),
        int(time()),
        consensus.getAggregate(
            [
                (blsPubKey2, 0, -1),
                (blsPubKey1, 6, -1)
            ]
        )
    ),
    BlockBody(
        [
            (
                blsPubKey2,
                3,
                consensus.getMerkle(
                    blsPubKey2,
                    0
                )
            ),
            (
                blsPubKey1,
                13,
                consensus.getMerkle(
                    blsPubKey1,
                    6
                )
            )
        ]
    )
)
block.header.rehash()
while int.from_bytes(block.header.hash, "big") < merit.blockchain.difficulty:
    block.header.proof += 1
    block.header.rehash()
merit.add(transactions, consensus, block)
print("Generated Fifty Block " + str(block.header.nonce) + ".")

#Save the appended data (3 Blocks and 12 Sends).
result: Dict[str, Any] = {
    "blockchain": merit.blockchain.toJSON(),
    "transactions": transactions.toJSON(),
    "consensus":  consensus.toJSON()
}
vectors: IO[Any] = open("python_tests/Vectors/Transactions/Fifty.json", "w")
vectors.write(json.dumps(result))
vectors.close()
