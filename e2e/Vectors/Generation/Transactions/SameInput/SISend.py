import json

import e2e.Libs.Ristretto.ed25519 as ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Send import Send
from e2e.Classes.Transactions.Claim import Claim
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

merit: Merit = PrototypeChain.withMint()
transactions: Transactions = Transactions()
sendFilter: SpamFilter = SpamFilter(3)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: bytes = edPrivKey.get_verifying_key()

claim: Claim = Claim([(merit.mints[-1], 0)], edPubKey)
claim.sign(PrivateKey(0))
transactions.add(claim)
merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[VerificationPacket(claim.hash, [0])]
  ).finish(0, merit)
)

#Create a Send spending it twice.
send: Send = Send(
  [(claim.hash, 0), (claim.hash, 0)],
  [(edPubKey, Claim.fromTransaction(transactions.txs[claim.hash]).amount * 2)]
)
send.sign(edPrivKey)
send.beat(sendFilter)
transactions.add(send)

merit.blockchain.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    [VerificationPacket(send.hash, [0])]
  ).finish(0, merit)
)

with open("e2e/Vectors/Transactions/SameInput/Send.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": merit.blockchain.toJSON(),
    "transactions": transactions.toJSON()
  }))
