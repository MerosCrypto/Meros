from typing import List
import json

import e2e.Libs.Ristretto.ed25519 as ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Claim, Send, Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: bytes = edPrivKey.get_verifying_key()

transactions: Transactions = Transactions()
sendFilter: SpamFilter = SpamFilter(3)

proto: PrototypeChain = PrototypeChain(40, keepUnlocked=True)
proto.add(1)
proto.add(2)
proto.add(3)
proto.add(4)
merit: Merit = Merit.fromJSON(proto.toJSON())

#Create a Claim and a Send splitting its outputs.
claim: Claim = Claim([(merit.mints[-1], 0)], edPubKey)
claim.sign(PrivateKey(0))
transactions.add(claim)

splitSend: Send = Send([(claim.hash, 0)], [(edPubKey, claim.amount // 2) for _ in range(2)])
splitSend.sign(edPrivKey)
splitSend.beat(sendFilter)
transactions.add(splitSend)

merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[
      VerificationPacket(claim.hash, list(range(5))),
      VerificationPacket(splitSend.hash, list(range(5)))
    ]
  ).finish(5, merit)
)

#We need to define two families. Family A (send output 0) and family B (send output 1).
sends: List[Send] = [
  #A.
  Send([(splitSend.hash, 0)], [(edPubKey, claim.amount // 2)]),
  Send([(splitSend.hash, 0)], [(bytes(32), claim.amount // 2)]),
  #B.
  Send([(splitSend.hash, 1)], [(edPubKey, claim.amount // 2)]),
  Send([(splitSend.hash, 1)], [(bytes(32), claim.amount // 2)]),
  #Now, union them.
  Send([(splitSend.hash, 0), (splitSend.hash, 1)], [(edPubKey, claim.amount)]),
]

for send in sends:
  send.sign(edPrivKey)
  send.beat(sendFilter)
  transactions.add(send)

#Finally, have the unionizing TX win.
merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[
      VerificationPacket(sends[4].hash, [0]),
      VerificationPacket(sends[0].hash, [1]),
      VerificationPacket(sends[1].hash, [2]),
      VerificationPacket(sends[2].hash, [3]),
      VerificationPacket(sends[3].hash, [4])
    ]
  ).finish(5, merit)
)

for _ in range(5):
  merit.add(
    PrototypeBlock(merit.blockchain.blocks[-1].header.time + 1200).finish(5, merit)
  )

with open("e2e/Vectors/Consensus/Families/UnionedFamiliesSingleWinner.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": merit.toJSON(),
    "transactions": transactions.toJSON(),
    "sends": [send.toJSON() for send in sends]
  }))
