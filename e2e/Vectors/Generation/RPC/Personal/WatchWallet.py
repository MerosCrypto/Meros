import json

import ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Claim, Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket

from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

edPubKey: bytes = ed25519.SigningKey(b'\0' * 32).get_verifying_key().to_bytes()

proto: PrototypeChain = PrototypeChain(49, keepUnlocked=True)
merit: Merit = Merit.fromJSON(proto.toJSON())

transactions: Transactions = Transactions()

#Create the Claims.
for m in range(3):
  claim: Claim = Claim([(merit.mints[m], 0)], edPubKey)
  claim.sign(PrivateKey(0))
  transactions.add(claim)

merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[VerificationPacket(tx.hash, [0]) for tx in transactions.txs.values()]
  ).finish(0, merit)
)

with open("e2e/Vectors/RPC/Personal/WatchWallet.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": merit.toJSON(),
    "transactions": transactions.toJSON()
  }))
