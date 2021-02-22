from typing import List
import json

import ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Transactions import Claim, Send, Data, Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SendDifficulty import SendDifficulty
from e2e.Classes.Consensus.DataDifficulty import DataDifficulty
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.Merit import Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

proto: PrototypeChain = PrototypeChain(7)
proto.add(1)
proto.add(2)
proto.add(3)
proto.add(4)
proto.add(elements=[SendDifficulty(1, 0, 2), SendDifficulty(1, 0, 4)])
merit: Merit = Merit.fromJSON(proto.toJSON())
transactions: Transactions = Transactions()

claim: Claim = Claim(
  [(merit.mints[-1], 0)],
  ed25519.SigningKey(b'\0' * 32).get_verifying_key().to_bytes()
)
claim.sign(PrivateKey(0))
transactions.add(claim)

send: Send = Send(
  [(claim.hash, 0)],
  [(ed25519.SigningKey(b'\1' * 32).get_verifying_key().to_bytes(), claim.amount)]
)
send.sign(ed25519.SigningKey(b'\0' * 32))
send.beat(SpamFilter(3))
transactions.add(send)

datas: List[Data] = [
  Data(bytes(32), ed25519.SigningKey(b'\0' * 32).get_verifying_key().to_bytes())
]
for _ in range(4):
  datas[-1].sign(ed25519.SigningKey(b'\0' * 32))
  datas[-1].beat(SpamFilter(5))
  transactions.add(datas[-1])
  datas.append(Data(datas[-1].hash, b'\0'))
del datas[-1]

merit.add(
  PrototypeBlock(
    merit.blockchain.blocks[-1].header.time + 1200,
    packets=[
      VerificationPacket(claim.hash, [0]),
      VerificationPacket(send.hash, [0, 1, 2]),
      VerificationPacket(datas[0].hash, [0, 2]),
      VerificationPacket(datas[1].hash, [0, 1, 3]),
      VerificationPacket(datas[2].hash, [0, 1, 2, 3, 4]),
      VerificationPacket(datas[3].hash, [0, 1, 2, 3])
    ],
    elements=[
      DataDifficulty(8, 0, 3),
      SendDifficulty(1, 0, 0),
      DataDifficulty(4, 0, 3),
      DataDifficulty(1, 2, 4),
      SendDifficulty(3, 1, 4),
      SendDifficulty(2, 1, 2),
      DataDifficulty(7, 0, 0),
    ]
  ).finish(0, merit)
)

with open("e2e/Vectors/RPC/Merit/GetBlock.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": merit.toJSON(),
    "transactions": transactions.toJSON(),
    "claim": claim.toJSON(),
    "send": send.toJSON(),
    "datas": [data.toJSON() for data in datas]
  }))
