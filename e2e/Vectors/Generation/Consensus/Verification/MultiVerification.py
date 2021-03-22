# Generates blocks with multiple verifications - these should be invalid.
from typing import Dict, List, Any
import json

import ed25519

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Send import Send
from e2e.Classes.Transactions.Transactions import Data, Transactions
from e2e.Classes.Transactions.Claim import Claim
from e2e.Classes.Transactions.Transaction import Transaction

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

transactions: Transactions = Transactions()
proto: PrototypeChain = PrototypeChain(40)
proto.add(1)
merit: Merit = Merit.fromJSON(proto.toJSON())

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()
blsPrivKey: PrivateKey = PrivateKey(0)


def apnAndDupli(transaction: Transaction):
  """Appends both a valid block (one verification) and an invalid version with two verifications."""
  transaction.sign(edPrivKey)
  # Highest spam filter will work no matter tranaction type.
  transaction.beat(SpamFilter(5))
  transactions.add(transaction)
  packet: VerificationPacket = VerificationPacket(transaction.hash, [0])
  # Generate a transaction with one verification.
  merit.add(
    PrototypeBlock(
      merit.blockchain.blocks[-1].header.time + 1200,
      packets=[packet],
      minerID=blsPrivKey
    ).finish(0, merit).toJSON()
  )
  # Generate a transaction with two verifications.
  merit.add(
    PrototypeBlock(
      merit.blockchain.blocks[-1].header.time + 1200,
      packets=[packet, packet],
      minerID=blsPrivKey
    ).finish(0, merit).toJSON()
  )

# Generate dual Data Transactions.
data: Data = Data(bytes(32), edPubKey.to_bytes())
apnAndDupli(data)
# Generate dual Claim Transactions
claim: Claim = Claim([(merit.mints[-1], 0)], edPubKey.to_bytes())
apnAndDupli(claim)
# Generate dual Send Transactions
send: Send = Send([(claim.hash, 0)], [edPubKey.to_bytes(), claim.amount])
apnAndDupli(send)

with open("e2e/Vectors/Consensus/Verification/MultiVerification.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": merit.toJSON(),
    "transactions": transactions.toJSON()
  }))
