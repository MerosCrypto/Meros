from typing import List, IO, Any
from hashlib import blake2b
import json

from ed25519 import SigningKey
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Transaction, Claim, Send, \
                                                  Transactions

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import GenerationError, \
                                                  PrototypeBlock, PrototypeChain

edPrivKey: SigningKey = SigningKey(blake2b(b"\0", digest_size=32).digest())
edPubKey: bytes = edPrivKey.get_verifying_key().to_bytes()
blsPrivKey: PrivateKey = PrivateKey(blake2b((0).to_bytes(2, "big"), digest_size=32).digest())

spamFilter: SpamFilter = SpamFilter(3)

#Create a Mint by mining 8 Blank Blocks.
#The first grants Merit; the second creates a Data; the third verifies the Data.
#The next 5 finalize the Data.
#We finalize/create a Merit out of it to access the Mint.
#We can't use the PrototypeChain directly due to the lack of actual hashes.
merit: Merit = Merit.fromJSON(PrototypeChain(7).finish().toJSON())
if len(merit.mints) != 1:
  raise GenerationError("HundredSeventyFive generator created the wrong amount of Mints.")

transactions: Transactions = Transactions()

#Used to get the most recent output to spend.
txs: List[Transaction] = []

#Create the Claim.
claim: Claim = Claim([(merit.mints[-1].hash, 0)], edPubKey)
claim.sign([blsPrivKey])
txs.append(claim)
transactions.add(claim)

#Create a Verification for this Claim.
verif: SignedVerification = SignedVerification(claim.hash)
verif.sign(0, blsPrivKey)

#Create two Sends, so the missing packets exceeds the capacity.
#This and the above Verification are used to actually test #175.
for s in range(2):
  send: Send = Send(
    [(txs[-1].hash, 0)],
    [(edPubKey, merit.mints[-1].outputs[0][1])]
  )
  send.sign(edPrivKey)
  send.beat(spamFilter)
  txs.append(send)
  transactions.add(send)

#Manually add the next Block.
#This wouldn't be needed if we could convert the Merit to a PrototypeChain.
#That said, this is easier than writing that algorithm.
#This remains true despite multiple generators needing this.
merit.blockchain.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    [VerificationPacket(tx.hash, [0]) for tx in txs]
  ).finish(
    #Don't bother verifying the Data.
    False,
    merit.blockchain.genesis,
    merit.blockchain.blocks[-1].header,
    merit.blockchain.difficulty(),
    [blsPrivKey]
  )
)

vectors: IO[Any] = open("e2e/Vectors/Merit/HundredSeventyFive.json", "w")
vectors.write(json.dumps({
  "blockchain": merit.toJSON(),
  "transactions": transactions.toJSON(),
  "verification": verif.toSignedJSON()
}))
vectors.close()
