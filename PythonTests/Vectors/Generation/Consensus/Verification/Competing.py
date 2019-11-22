#Types.
from typing import IO, Dict, List, Any

#Transactions classes.
from PythonTests.Classes.Transactions.Claim import Claim
from PythonTests.Classes.Transactions.Send import Send
from PythonTests.Classes.Transactions.Transactions import Transactions

#SpamFilter class.
from PythonTests.Classes.Consensus.SpamFilter import SpamFilter

#Verification classes.
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket

#Blockchain classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Merit import Blockchain

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
#Blockchain.
blockchain: Blockchain = Blockchain.fromJSON(
    b"MEROS_DEVELOPER_NETWORK",
    60,
    int("FAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 16),
    cmVectors["blockchain"]
)
cmFile.close()

#Spam Filter.
sendFilter: SpamFilter = SpamFilter(
    bytes.fromhex(
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    )
)

#Ed25519 keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKeys: List[ed25519.VerifyingKey] = [
    edPrivKey.get_verifying_key(),
    ed25519.SigningKey(b'\1' * 32).get_verifying_key()
]

#BLS keys.
blsPrivKeys: List[blspy.PrivateKey] = [
    blspy.PrivateKey.from_seed(b'\0'),
    blspy.PrivateKey.from_seed(b'\1')
]
blsPubKeys: List[blspy.PublicKey] = [
    blsPrivKeys[0].get_public_key(),
    blsPrivKeys[1].get_public_key()
]

#Grab the claim hash.
claim: bytes = blockchain.blocks[-1].body.packets[0].hash

#Give the second key pair Merit.
block: Block = Block(
    BlockHeader(
        0,
        blockchain.last(),
        bytes(48),
        1,
        bytes(4),
        blsPubKeys[1].serialize(),
        int(time())
    ),
    BlockBody([], [], bytes(96))
)

#Mine it.
block.mine(blsPrivKeys[1], blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated Competing Block " + str(len(blockchain.blocks)) + ".")

#Create two competing Sends.
packets: List[VerificationPacket] = []
toAggregate: List[blspy.Signature] = []
verif: SignedVerification
for i in range(2):
    send: Send = Send(
        [(claim, 0)],
        [(
            edPubKeys[i].to_bytes(),
            Claim.fromTransaction(transactions.txs[claim]).amount
        )]
    )
    send.sign(edPrivKey)
    send.beat(sendFilter)
    transactions.add(send)

    packets.append(VerificationPacket(send.hash, [i]))

    verif = SignedVerification(send.hash)
    verif.sign(i, blsPrivKeys[i])
    toAggregate.append(verif.blsSignature)

#Archive the Packets and close the Epoch.
block = Block(
    BlockHeader(
        0,
        blockchain.last(),
        BlockHeader.createContents(bytes(4), packets, []),
        1,
        bytes(4),
        0,
        int(time())
    ),
    BlockBody(packets, [], blspy.Signature.aggregate(toAggregate).serialize())
)
for _ in range(6):
    #Mine it.
    block.mine(blsPrivKeys[0], blockchain.difficulty())

    #Add it.
    blockchain.add(block)
    print("Generated Competing Block " + str(len(blockchain.blocks)) + ".")

    #Create the next Block.
    block = Block(
        BlockHeader(
            0,
            blockchain.last(),
            BlockHeader.createContents(),
            1,
            bytes(4),
            0,
            int(time())
        ),
        BlockBody([], [], bytes(96))
    )

#Save the appended data (3 Blocks and 12 Sends).
result: Dict[str, Any] = {
    "blockchain": blockchain.toJSON(),
    "transactions": transactions.toJSON()
}
vectors: IO[Any] = open("PythonTests/Vectors/Consensus/Verification/Competing.json", "w")
vectors.write(json.dumps(result))
vectors.close()
