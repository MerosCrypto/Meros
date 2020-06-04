#Types.
from typing import IO, Dict, List, Tuple, Union, Any

#BLS lib.
from e2e.Libs.BLS import PrivateKey, PublicKey, Signature

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
blsPrivKeys: List[PrivateKey] = [
  PrivateKey(blake2b(b'\0', digest_size=32).digest()),
  PrivateKey(blake2b(b'\1', digest_size=32).digest())
]
blsPubKeys: List[PublicKey] = [
  blsPrivKeys[0].toPublicKey(),
  blsPrivKeys[1].toPublicKey()
]

#Grab the Claim hash.
claim: bytes = blockchain.blocks[-1].body.packets[0].hash

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
  sends[-1].beat(sendFilter)
  transactions.add(sends[-1])

  sends.append(
    Send(
      [(sends[-1].hash, 0)],
      [(edPubKey.to_bytes(), sends[-1].outputs[0][1])]
    )
  )

#Order to verify the Transactions in.
#Dict key is holder nick.
#Dict value is list of transactions.
#Tuple's second value is miner.
orders: List[Tuple[Dict[int, List[int]], Union[bytes, int]]] = [
  #Verify the first two Merit Holders.
  ({0: [0, 1]}, 0),
  #Verify 3, and then 2, while giving Merit to a second Merit Holder.
  ({0: [3, 2]}, blsPubKeys[1].serialize()),
  #Verify every other TX.
  ({1: [5, 6, 9, 11, 3, 0], 0: [4, 5, 8, 7, 11, 6, 10, 9]}, 1)
]
#Packets.
packets: Dict[int, VerificationPacket]
toAggregate: List[Signature]

#Add each Block.
for order in orders:
  #Clear old data.
  packets = {}
  toAggregate = []

  for h in order[0]:
    for s in order[0][h]:
      if s not in packets:
        packets[s] = VerificationPacket(sends[s].hash, [])
      packets[s].holders.append(h)

      verif: SignedVerification = SignedVerification(sends[s].hash)
      verif.sign(h, blsPrivKeys[h])
      toAggregate.append(verif.signature)

  block: Block = Block(
    BlockHeader(
      0,
      blockchain.last(),
      BlockHeader.createContents(list(packets.values())),
      1,
      bytes(4),
      BlockHeader.createSketchCheck(bytes(4), list(packets.values())),
      order[1],
      blockchain.blocks[-1].header.time + 1200
    ),
    BlockBody(list(packets.values()), [], Signature.aggregate(toAggregate))
  )

  miner: Union[bytes, int] = order[1]
  if isinstance(miner, bytes):
    for k in range(len(blsPubKeys)):
      if miner == blsPubKeys[k].serialize():
        block.mine(blsPrivKeys[k], blockchain.difficulty())
        break
  else:
    block.mine(blsPrivKeys[miner], blockchain.difficulty())

  blockchain.add(block)
  print("Generated Fifty Block " + str(len(blockchain.blocks) - 1) + ".")

#Generate another 5 Blocks.
for _ in range(5):
  #Create the next Block.
  block: Block = Block(
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

  #Mine it.
  block.mine(blsPrivKeys[0], blockchain.difficulty())

  #Add it.
  blockchain.add(block)
  print("Generated Fifty Block " + str(len(blockchain.blocks) - 1) + ".")

#Save the vector.
result: Dict[str, Any] = {
  "blockchain": blockchain.toJSON(),
  "transactions": transactions.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Transactions/Fifty.json", "w")
vectors.write(json.dumps(result))
vectors.close()
