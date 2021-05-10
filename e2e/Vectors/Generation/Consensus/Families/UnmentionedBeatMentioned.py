from typing import List
import json

import e2e.Libs.Ristretto.Ristretto as Ristretto
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

dataFilter: SpamFilter = SpamFilter(5)

edPrivKey: Ristretto.SigningKey = Ristretto.SigningKey(b'\0' * 32)
edPubKey: bytes = edPrivKey.get_verifying_key()

proto: PrototypeChain = PrototypeChain(40, keepUnlocked=True)
proto.add(1)

datas: List[Data] = [Data(bytes(32), edPubKey)]
for d in range(2):
  datas.append(Data(datas[0].hash, d.to_bytes(1, "little")))
for data in datas:
  data.sign(edPrivKey)
  data.beat(dataFilter)

verif: SignedVerification = SignedVerification(datas[1].hash)
verif.sign(0, PrivateKey(0))
proto.add(
  packets=[
    VerificationPacket(datas[0].hash, [0]),
    VerificationPacket(datas[2].hash, [1])
  ]
)

for _ in range(5):
  proto.add()

with open("e2e/Vectors/Consensus/Families/UnmentionedBeatMentioned.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": proto.toJSON(),
    "datas": [data.toJSON() for data in datas],
    "verification": verif.toSignedJSON()
  }))
