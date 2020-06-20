from typing import IO, Any
import json

import ed25519

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

transactions: Transactions = Transactions()
spamFilter: SpamFilter = SpamFilter(5)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

proto: PrototypeChain = PrototypeChain(5)
for _ in range(80):
  proto.add(1)

for _ in range(14):
  proto.add(2)

data: Data = Data(bytes(32), edPubKey.to_bytes())
data.sign(edPrivKey)
data.beat(spamFilter)
transactions.add(data)

proto.add(2, [VerificationPacket(data.hash, [0, 1])])

#Close out the Epoch.
for _ in range(6):
  proto.add(2)

vectors: IO[Any] = open("e2e/Vectors/Consensus/Verification/HundredTwo.json", "w")
vectors.write(json.dumps({
  "blockchain": proto.finish().toJSON(),
  "transactions": transactions.toJSON()
}))
vectors.close()
