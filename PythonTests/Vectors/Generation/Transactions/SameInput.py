#Types.
from typing import IO, Dict, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, PublicKey

#Transactions classes.
from PythonTests.Classes.Transactions.Send import Send
from PythonTests.Classes.Transactions.Claim import Claim
from PythonTests.Classes.Transactions.Transactions import Transactions

#SpamFilter class.
from PythonTests.Classes.Consensus.SpamFilter import SpamFilter

#SignedVerification and VerificationPacket classes.
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.VerificationPacket import VerificationPacket

#Blockchain classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Ed25519 lib.
import ed25519

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

cmFile: IO[Any] = open("PythonTests/Vectors/Transactions/ClaimedMint.json", "r")
cmVectors: Dict[str, Any] = json.loads(cmFile.read())
#Transactions.
transactions: Transactions = Transactions.fromJSON(cmVectors["transactions"])
#Blockchain.
blockchain: Blockchain = Blockchain.fromJSON(cmVectors["blockchain"])
cmFile.close()

#SpamFilter.
sendFilter: SpamFilter = SpamFilter(bytes.fromhex("AA" * 32))

#Ed25519 keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#BLS keys.
blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Grab the Claim hash.
claim: bytes = blockchain.blocks[-1].body.packets[0].hash

#Create a Send spending it twice.
send: Send = Send(
    [(claim, 0), (claim, 0)],
    [(
        edPubKey.to_bytes(),
        Claim.fromTransaction(transactions.txs[claim]).amount * 2
    )]
)
send.sign(edPrivKey)
send.beat(sendFilter)
transactions.add(send)

#Create a Verification/VerificationPacket for the Send.
sv: SignedVerification = SignedVerification(send.hash)
sv.sign(0, blsPrivKey)
packet: VerificationPacket = VerificationPacket(send.hash, [0])

#Add a Block verifying it.
block: Block = Block(
    BlockHeader(
        0,
        blockchain.last(),
        BlockHeader.createContents([packet]),
        1,
        bytes(4),
        BlockHeader.createSketchCheck(bytes(4), [packet]),
        0,
        blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody([packet], [], sv.signature)
)

#Mine the Block.
block.mine(blsPrivKey, blockchain.difficulty())

#Add the Block.
blockchain.add(block)
print("Generated Same Input Block " + str(len(blockchain.blocks) - 1) + ".")

#Save the vector.
result: Dict[str, Any] = {
    "blockchain": blockchain.toJSON(),
    "transactions": transactions.toJSON()
}
vectors: IO[Any] = open("PythonTests/Vectors/Transactions/SameInput.json", "w")
vectors.write(json.dumps(result))
vectors.close()
