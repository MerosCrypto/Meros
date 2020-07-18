from typing import IO, Dict, List, Any
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

proto: PrototypeChain = PrototypeChain(1)

#Create the original Data.
datas: List[Data] = [Data(bytes(32), edPubKey.to_bytes())]
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

result: Dict[str, Any] = {
  "blockchain": proto.toJSON(),
  "datas": [datas[0].toJSON(), datas[1].toJSON(), datas[2].toJSON(), datas[3].toJSON()],
  "verification": descendantVerif.toSignedJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Transactions/PruneUnaddable.json", "w")
vectors.write(json.dumps(result))
vectors.close()
