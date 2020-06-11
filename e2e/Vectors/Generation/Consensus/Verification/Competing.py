from typing import IO, Dict, List, Any
from hashlib import blake2b
import json

import ed25519
from e2e.Libs.BLS import PrivateKey, PublicKey, Signature

from e2e.Classes.Transactions.Claim import Claim
from e2e.Classes.Transactions.Send import Send
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Merit import Blockchain

cmFile: IO[Any] = open("e2e/Vectors/Transactions/ClaimedMint.json", "r")
cmVectors: Dict[str, Any] = json.loads(cmFile.read())
transactions: Transactions = Transactions.fromJSON(cmVectors["transactions"])
blockchain: Blockchain = Blockchain.fromJSON(cmVectors["blockchain"])
cmFile.close()

sendFilter: SpamFilter = SpamFilter(3)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKeys: List[ed25519.VerifyingKey] = [
  edPrivKey.get_verifying_key(),
  ed25519.SigningKey(b'\1' * 32).get_verifying_key()
]

blsPrivKeys: List[PrivateKey] = [
  PrivateKey(blake2b(b'\0', digest_size=32).digest()),
  PrivateKey(blake2b(b'\1', digest_size=32).digest())
]
blsPubKeys: List[PublicKey] = [
  blsPrivKeys[0].toPublicKey(),
  blsPrivKeys[1].toPublicKey()
]

#Grab the claim hash.
claim: bytes = blockchain.blocks[-1].body.packets[0].hash

#Give the second key pair Merit.
block: Block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    bytes(32),
    1,
    bytes(4),
    bytes(32),
    blsPubKeys[1].serialize(),
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody()
)
block.mine(blsPrivKeys[1], blockchain.difficulty())
blockchain.add(block)
print("Generated Competing Block " + str(len(blockchain.blocks)) + ".")

#Create two competing Sends.
packets: List[VerificationPacket] = []
toAggregate: List[Signature] = []
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
  toAggregate.append(verif.signature)

#Archive the Packets and close the Epoch.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents(packets),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), packets),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody(packets, [], Signature.aggregate(toAggregate))
)
for _ in range(6):
  block.mine(blsPrivKeys[0], blockchain.difficulty())
  blockchain.add(block)
  print("Generated Competing Block " + str(len(blockchain.blocks)) + ".")

  #Create the next Block.
  block = Block(
    BlockHeader(
      0,
      blockchain.last(),
      bytes(32),
      1,
      bytes(4),
      bytes(32),
      0,
      blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody()
  )

#Save the appended data (3 Blocks and 12 Sends).
result: Dict[str, Any] = {
  "blockchain": blockchain.toJSON(),
  "transactions": transactions.toJSON(),
  "verified": packets[0].hash.hex().upper(),
  "beaten": packets[1].hash.hex().upper()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/Verification/Competing.json", "w")
vectors.write(json.dumps(result))
vectors.close()
