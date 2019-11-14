"""
#Types.
from typing import IO, Dict, List, Any

#Transactions classes.
from PythonTests.Classes.Transactions.Send import Send
from PythonTests.Classes.Transactions.Claim import Claim
from PythonTests.Classes.Transactions.Transactions import Transactions

#Consensus class.
from PythonTests.Classes.Consensus.Verification import Verification, SignedVerification
from PythonTests.Classes.Consensus.Consensus import Consensus

#Blockchain classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Ed25519 lib.
import ed25519

#BLS lib.
import blspy

#Time standard function.
from time import time

#JSON standard lib.
import json

cmFile: IO[Any] = open("PythonTests/Vectors/Transactions/ClaimedMint.json", "r")
cmVectors: Dict[str, Any] = json.loads(cmFile.read())
#Transactions.
transactions: Transactions = Transactions.fromJSON(cmVectors["transactions"])
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
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#BLS keys.
blsPrivKey1: blspy.PrivateKey = blspy.PrivateKey.from_seed(b'\0')
blsPubKey1: blspy.PublicKey = blsPrivKey1.get_public_key()

blsPrivKey2: blspy.PrivateKey = blspy.PrivateKey.from_seed(b'\1')
blsPubKey2: blspy.PublicKey = blsPrivKey2.get_public_key()

#Grab the claim hash.
claim: bytes = Verification.fromElement(consensus.holders[blsPubKey1.serialize()][1]).txHash

#Create 12 Sends.
sends: List[Send] = []
sends.append(
    Send(
        [(claim, 0)],
        [(
            edPubKey.to_bytes(),
            Claim.fromTransaction(transactions.txs[claim]).amount
        )]
    )
)
for _ in range(12):
    sends[-1].sign(edPrivKey)
    sends[-1].beat(consensus.sendFilter)
    sends[-1].verified = True
    transactions.add(sends[-1])

    sends.append(
        Send(
            [(sends[-1].txHash, 0)],
            [(edPubKey.to_bytes(), sends[-1].outputs[0][1])]
        )
    )

#Verify 0 and 1 in order.
order: List[int] = [0, 1]
verif: SignedVerification
for s in order:
    verif = SignedVerification(sends[s].txHash)
    verif.sign(blsPrivKey1, len(consensus.holders[blsPubKey1.serialize()]))
    consensus.add(verif)

block: Block = Block(
    BlockHeader(
        13,
        blockchain.last(),
        int(time()),
        consensus.getAggregate([(blsPubKey1, 2, -1)])
    ),
    BlockBody([(blsPubKey1, 3, consensus.getMerkle(blsPubKey1, 2))])
)
block.mine(blockchain.difficulty())
blockchain.add(block)
print("Generated Fifty Block " + str(block.header.nonce) + ".")

#Verify 3, and then 2, while giving Merit to a second Merit Holder.
order = [3, 2]
for s in order:
    verif = SignedVerification(sends[s].txHash)
    verif.sign(blsPrivKey1, len(consensus.holders[blsPubKey1.serialize()]))
    consensus.add(verif)

block = Block(
    BlockHeader(
        14,
        blockchain.last(),
        int(time()),
        consensus.getAggregate([(blsPubKey1, 4, -1)])
    ),
    BlockBody(
        [(blsPubKey1, 5, consensus.getMerkle(blsPubKey1, 4))],
        [(blsPubKey2, 100)]
    )
)
block.mine(blockchain.difficulty())
blockchain.add(block)
print("Generated Fifty Block " + str(block.header.nonce) + ".")

#2nd Merit Holder:
order = [5, 6, 9, 11]
for i in range(len(order)):
    verif = SignedVerification(sends[order[i]].txHash)
    verif.sign(blsPrivKey2, i)
    consensus.add(verif)

#1st Merit Holder:
order = [4, 5, 8, 7, 11, 6, 10, 9]
for s in order:
    verif = SignedVerification(sends[s].txHash)
    verif.sign(blsPrivKey1, len(consensus.holders[blsPubKey1.serialize()]))
    consensus.add(verif)

block = Block(
    BlockHeader(
        15,
        blockchain.last(),
        int(time()),
        consensus.getAggregate([(blsPubKey2, 0, -1), (blsPubKey1, 6, -1)])
    ),
    BlockBody(
        [
            (blsPubKey2, 3, consensus.getMerkle(blsPubKey2, 0)),
            (blsPubKey1, 13, consensus.getMerkle(blsPubKey1, 6))
        ]
    )
)
block.mine(blockchain.difficulty())
blockchain.add(block)
print("Generated Fifty Block " + str(block.header.nonce) + ".")

#Generate another 5 Blocks.
for i in range(16, 21):
    #Create the next Block.
    block = Block(BlockHeader(i, blockchain.last(), int(time())), BlockBody())

    #Mine it.
    block.mine(blockchain.difficulty())

    #Add it.
    blockchain.add(block)
    print("Generated Fifty Block " + str(block.header.nonce) + ".")

#Save the appended data (3 Blocks and 12 Sends).
result: Dict[str, Any] = {
    "blockchain": blockchain.toJSON(),
    "transactions": transactions.toJSON(),
    "consensus":  consensus.toJSON()
}
vectors: IO[Any] = open("PythonTests/Vectors/Transactions/Fifty.json", "w")
vectors.write(json.dumps(result))
vectors.close()
"""
