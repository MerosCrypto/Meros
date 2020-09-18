from typing import List
import json

import ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

dataFilter: SpamFilter = SpamFilter(5)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

proto: PrototypeChain = PrototypeChain(40, keepUnlocked=True)

datas: List[Data] = [Data(bytes(32), edPubKey.to_bytes())]
for d in range(2):
  datas.append(Data(datas[0].hash, d.to_bytes(1, "little")))
for data in datas:
  data.sign(edPrivKey)
  data.beat(dataFilter)

proto.add(1)
proto.add(2)
proto.add(packets=[VerificationPacket(datas[0].hash, [0, 1, 2])])
proto.add(packets=[VerificationPacket(datas[1].hash, [0])])
proto.add(packets=[VerificationPacket(datas[2].hash, [1])])

verif: SignedVerification = SignedVerification(datas[2].hash)
verif.sign(2, PrivateKey(2))

for _ in range(5):
  proto.add()

with open("e2e/Vectors/Transactions/Prune/TwoHundredThirtyEight.json", "w") as vectors:
  vectors.write(
    json.dumps({
      "blockchain": proto.toJSON(),
      "datas": [data.toJSON() for data in datas],
      "verification": verif.toSignedJSON()
    })
  )
