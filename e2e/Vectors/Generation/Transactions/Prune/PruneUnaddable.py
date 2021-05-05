from typing import List
import json

import e2e.Libs.Ristretto.ed25519 as ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

dataFilter: SpamFilter = SpamFilter(5)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: bytes = edPrivKey.get_verifying_key()

proto: PrototypeChain = PrototypeChain(1, keepUnlocked=False)

#Create the original Data.
datas: List[Data] = [Data(bytes(32), edPubKey)]
datas[0].sign(edPrivKey)
datas[0].beat(dataFilter)

#Create two competing Datas, where only the first will be verified.
for d in range(2):
  datas.append(Data(datas[0].hash, d.to_bytes(1, "little")))
  datas[1 + d].sign(edPrivKey)
  datas[1 + d].beat(dataFilter)

#Create a Data that's a descendant of the Data which will be beaten.
datas.append(Data(datas[2].hash, (2).to_bytes(1, "little")))
datas[3].sign(edPrivKey)
datas[3].beat(dataFilter)

#Create a SignedVerification for the descendant Data.
descendantVerif: SignedVerification = SignedVerification(datas[1].hash)
descendantVerif.sign(0, PrivateKey(0))

#Add the packets and close the Epochs.
proto.add(packets=[
  VerificationPacket(datas[0].hash, [0]),
  VerificationPacket(datas[1].hash, [0])
])
for _ in range(5):
  proto.add()

with open("e2e/Vectors/Transactions/Prune/PruneUnaddable.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": proto.toJSON(),
    "datas": [data.toJSON() for data in datas],
    "verification": descendantVerif.toSignedJSON()
  }))
