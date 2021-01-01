import json

import ed25519

from e2e.Classes.Transactions.Transactions import Data, Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
dataFilter: SpamFilter = SpamFilter(5)
transactions: Transactions = Transactions()
proto: PrototypeChain = PrototypeChain(1)

#Create five Datas.
#Six in total, thanks to the Block Data.
data: Data = Data(bytes(32), edPrivKey.get_verifying_key().to_bytes())
for i in range(5):
  data.sign(edPrivKey)
  data.beat(dataFilter)
  transactions.add(data)
  data = Data(data.hash, b"\0")

#Create a Block verifying all of them.
proto.add(0, [VerificationPacket(tx.hash, [0]) for tx in transactions.txs.values()])

with open("e2e/Vectors/Merit/TwoHundredSeventyFour/RespondsWithRequestedCapacity.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": proto.toJSON(),
    "transactions": transactions.toJSON()
  }))
