import json

import ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Claim import Claim
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket

from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

merit: Merit = Merit.fromJSON(PrototypeChain(49).toJSON())
transactions: Transactions = Transactions()

olderClaim: Claim = Claim(
  [(merit.mints[-2], 0)],
  ed25519.SigningKey(b'\0' * 32).get_verifying_key().to_bytes()
)
olderClaim.sign(PrivateKey(0))
transactions.add(olderClaim)

newerClaim: Claim = Claim(
  [(merit.mints[-1], 0)],
  ed25519.SigningKey(b'\0' * 32).get_verifying_key().to_bytes()
)
newerClaim.sign(PrivateKey(0))
transactions.add(newerClaim)

merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[VerificationPacket(olderClaim.hash, [0]), VerificationPacket(newerClaim.hash, [0])]
  ).finish(0, merit)
)

with open("e2e/Vectors/RPC/Transactions/GetUTXOs.json", "w") as vectors:
  #olderMint/newerMint are short for olderMintClaim/newerMintClaim.
  vectors.write(json.dumps({
    "blockchain": merit.toJSON(),
    "transactions": transactions.toJSON(),
    "olderMint": olderClaim.toJSON(),
    "newerMint": newerClaim.toJSON()
  }))
