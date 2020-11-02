from typing import List
import json

import ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Claim, Send, Transactions

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.Merit import Block, Merit

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
  ).finish(0, merit)
)

sends: List[Send] = [
  #Transaction which will win.
  Send([(claim.hash, 0)], [(bytes(32), claim.amount)]),
  #Transaction which will be beaten.
  Send([(claim.hash, 0)], [(edPubKey, claim.amount // 2), (edPubKey, claim.amount // 2)])
]
#Children. One which will have a Verification, one which won't.
sends += [
  Send([(sends[1].hash, 0)], [(edPubKey, claim.amount // 2)]),
  Send([(sends[1].hash, 1)], [(edPubKey, claim.amount // 2)])
]

#Send which spend the remaining descendant of the beaten Transaction.
sends.append(Send([(sends[2].hash, 0)], [(bytes(32), claim.amount // 2)]))

for s in range(len(sends)):
  sends[s].sign(edPrivKey)
  sends[s].beat(sendFilter)
  if s < 3:
    transactions.add(sends[s])

verif: SignedVerification = SignedVerification(sends[2].hash, 1)
verif.sign(1, PrivateKey(1))

merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[
      VerificationPacket(sends[0].hash, [0]),
      VerificationPacket(sends[1].hash, [1])
    ]
  ).finish(0, merit)
)

merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[VerificationPacket(sends[2].hash, [0])]
  ).finish(0, merit)
)

for _ in range(4):
  merit.add(
    PrototypeBlock(merit.blockchain.blocks[-1].header.time + 1200).finish(0, merit)
  )

blockWBeatenVerif: Block = PrototypeBlock(
  merit.blockchain.blocks[-1].header.time + 1200,
  packets=[VerificationPacket(sends[2].hash, [1])]
).finish(0, merit)

merit.add(
  PrototypeBlock(merit.blockchain.blocks[-1].header.time + 1200).finish(0, merit)
)

with open("e2e/Vectors/Consensus/Beaten.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": merit.toJSON(),
    "transactions": transactions.toJSON(),
    "sends": [send.toJSON() for send in sends],
    "verification": verif.toSignedJSON(),
    "blockWithBeatenVerification": blockWBeatenVerif.toJSON()
  }))
