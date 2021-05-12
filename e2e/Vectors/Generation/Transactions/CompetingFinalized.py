import json

import e2e.Libs.Ristretto.Ristretto as Ristretto

from e2e.Classes.Transactions.Transactions import Data, Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

transactions: Transactions = Transactions()
dataFilter: SpamFilter = SpamFilter(5)

edPrivKey: Ristretto.SigningKey = Ristretto.SigningKey(b'\0' * 32)
edPubKey: bytes = edPrivKey.get_verifying_key()

proto: PrototypeChain = PrototypeChain(1, keepUnlocked=False)

#Create the Data and a successor.
first: Data = Data(bytes(32), edPubKey)
first.sign(edPrivKey)
first.beat(dataFilter)
transactions.add(first)

second: Data = Data(first.hash, bytes(1))
second.sign(edPrivKey)
second.beat(dataFilter)
transactions.add(second)

proto.add(
  packets=[
    VerificationPacket(first.hash, [0]),
    VerificationPacket(second.hash, [0])
  ]
)

for _ in range(5):
  proto.add()

#Create a Data competing with the now-finalized second Data.
competitor: Data = Data(first.hash, bytes(2))
competitor.sign(edPrivKey)
competitor.beat(dataFilter)
transactions.add(competitor)

proto.add(packets=[VerificationPacket(competitor.hash, [0])])

with open("e2e/Vectors/Transactions/CompetingFinalized.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": proto.toJSON(),
    "transactions": transactions.toJSON()
  }))
