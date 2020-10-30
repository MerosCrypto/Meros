from typing import List
import json

import ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Claim, Send, Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: bytes = edPrivKey.get_verifying_key().to_bytes()

transactions: Transactions = Transactions()
sendFilter: SpamFilter = SpamFilter(3)

proto: PrototypeChain = PrototypeChain(40, keepUnlocked=True)
proto.add(1)
merit: Merit = Merit.fromJSON(proto.toJSON())

#Create a Claim.
claim: Claim = Claim([(merit.mints[-1], 0)], edPubKey)
claim.sign(PrivateKey(0))
transactions.add(claim)

merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[VerificationPacket(claim.hash, list(range(2)))]
  ).finish(2, merit)
)

sends: List[Send] = [Send([(claim.hash, 0)], [(edPubKey, claim.amount)])]
sends.append(Send([(claim.hash, 0), (sends[0].hash, 0)], [(edPubKey, claim.amount * 2)]))

for send in sends:
  send.sign(edPrivKey)
  send.beat(sendFilter)
  transactions.add(send)

#Verify the 'impossible' TX, mentioning the only possible one.
merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[
      VerificationPacket(sends[1].hash, [0]),
      VerificationPacket(sends[0].hash, [1])
    ]
  ).finish(2, merit)
)

for _ in range(5):
  merit.add(
    PrototypeBlock(merit.blockchain.blocks[-1].header.time + 1200).finish(2, merit)
  )

with open("e2e/Vectors/Consensus/Families/ImpossibleFamily.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": merit.toJSON(),
    "transactions": transactions.toJSON(),
    "sends": [send.toJSON() for send in sends]
  }))
