from typing import List
import json

import e2e.Libs.Ristretto.Ristretto as Ristretto
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Claim, Send, Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

edPrivKey: Ristretto.SigningKey = Ristretto.SigningKey(b'\0' * 32)
edPubKey: bytes = edPrivKey.get_verifying_key()

transactions: Transactions = Transactions()
sendFilter: SpamFilter = SpamFilter(3)

proto: PrototypeChain = PrototypeChain(40, keepUnlocked=True)
for _ in range(2):
  proto.add(1)
proto.add(2)
proto.add(3)
merit: Merit = Merit.fromJSON(proto.toJSON())

#Create a Claim.
claim: Claim = Claim([(merit.mints[-1], 0)], edPubKey)
claim.sign(PrivateKey(0))
transactions.add(claim)

merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[VerificationPacket(claim.hash, list(range(4)))]
  ).finish(4, merit)
)

sends: List[Send] = [
  #Competitors.
  Send([(claim.hash, 0)], [(bytes(32), claim.amount)]),
  Send([(claim.hash, 0)], [(edPubKey, claim.amount)])
]
#Descendant, which will have more Merit than the parents.
sends.append(Send([(sends[1].hash, 0)], [(edPubKey, claim.amount)]))
#Finally, a transaction to force them all into the same family.
sends.append(Send([(claim.hash, 0), (sends[1].hash, 0)], [(edPubKey, claim.amount * 2)]))

for send in sends:
  send.sign(edPrivKey)
  send.beat(sendFilter)
  transactions.add(send)

#Finally, have the unionizing TX win.
merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[
      #Descendant gets the most Merit. Then, the parent gets enough to beat its competitor.
      VerificationPacket(sends[2].hash, [0]),
      VerificationPacket(sends[1].hash, [1]),
      #The others are solely mentioned.
      VerificationPacket(sends[0].hash, [2]),
      VerificationPacket(sends[3].hash, [3])
    ]
  ).finish(4, merit)
)

for _ in range(5):
  merit.add(
    PrototypeBlock(merit.blockchain.blocks[-1].header.time + 1200).finish(4, merit)
  )

with open("e2e/Vectors/Consensus/Families/DescendantHighestVerifiedParent.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": merit.toJSON(),
    "transactions": transactions.toJSON(),
    "sends": [send.toJSON() for send in sends]
  }))
