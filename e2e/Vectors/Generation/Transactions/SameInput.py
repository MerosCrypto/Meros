#Types.
from typing import IO, Dict, Any

#BLS lib.
from e2e.Libs.BLS import PrivateKey, PublicKey

#Transactions classes.
from e2e.Classes.Transactions.Send import Send
from e2e.Classes.Transactions.Claim import Claim
from e2e.Classes.Transactions.Transactions import Transactions

#SpamFilter class.
from e2e.Classes.Consensus.SpamFilter import SpamFilter

#SignedVerification and VerificationPacket classes.
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket

#Blockchain classes.
from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

#Ed25519 lib.
import ed25519

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

cmFile: IO[Any] = open("e2e/Vectors/Transactions/ClaimedMint.json", "r")
cmVectors: Dict[str, Any] = json.loads(cmFile.read())
#Transactions.
transactions: Transactions = Transactions.fromJSON(cmVectors["transactions"])
#Blockchain.
blockchain: Blockchain = Blockchain.fromJSON(cmVectors["blockchain"])
cmFile.close()

#SpamFilter.
sendFilter: SpamFilter = SpamFilter(3)

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
vectors: IO[Any] = open("e2e/Vectors/Transactions/SameInput.json", "w")
vectors.write(json.dumps(result))
vectors.close()
