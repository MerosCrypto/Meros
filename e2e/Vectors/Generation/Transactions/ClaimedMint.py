import json

import e2e.Libs.Ristretto.Ristretto as Ristretto
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Claim import Claim
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket

from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

merit: Merit = PrototypeChain.withMint()
transactions: Transactions = Transactions()

claim: Claim = Claim(
  [(merit.mints[-1], 0)],
  Ristretto.SigningKey(b'\0' * 32).get_verifying_key()
)
claim.sign(PrivateKey(0))
transactions.add(claim)

merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[VerificationPacket(claim.hash, [0])]
  ).finish(0, merit)
)

with open("e2e/Vectors/Transactions/ClaimedMint.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": merit.toJSON(),
    "transactions": transactions.toJSON()
  }))
