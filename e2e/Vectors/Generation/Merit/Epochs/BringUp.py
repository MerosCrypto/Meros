from typing import List
import json

import e2e.Libs.Ristretto.Ristretto as Ristretto

from e2e.Classes.Transactions.Transactions import Data, Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

edPrivKey: Ristretto.SigningKey = Ristretto.SigningKey(b'\0' * 32)
edPubKey: bytes = edPrivKey.get_verifying_key()

transactions: Transactions = Transactions()
datas: List[Data] = []
for i in range(4):
  inputHash: bytes = bytes()
  #Initial.
  if i == 0:
    inputHash = bytes(32)
  #Base.
  elif i == 1:
    inputHash = datas[0].hash
  #Child.
  elif i == 2:
    inputHash = datas[1].hash
  #Competing.
  elif i == 3:
    inputHash = datas[0].hash
  datas.append(Data(inputHash, edPubKey if i != 3 else bytes(1)))
  datas[-1].sign(edPrivKey)
  transactions.add(datas[-1])

proto: PrototypeChain = PrototypeChain(1, keepUnlocked=True)
proto.add(packets=[VerificationPacket(datas[0].hash, [0]), VerificationPacket(datas[1].hash, [0])])
proto.add(1, packets=[VerificationPacket(datas[2].hash, [0])])
proto.add(packets=[VerificationPacket(datas[3].hash, [1])])

#Finalize everything.
for _ in range(5):
  proto.add()

with open("e2e/Vectors/Merit/Epochs/BringUp.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": proto.toJSON(),
    "transactions": transactions.toJSON(),
    "datas": [data.toJSON() for data in datas]
  }))
