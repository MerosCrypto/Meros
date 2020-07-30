from typing import IO, List, Any
import json

import ed25519

from e2e.Libs.Minisketch import Sketch

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.VerificationPacket import VerificationPacket

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

proto: PrototypeChain = PrototypeChain(1, keepUnlocked=False)
datas: List[Data] = [Data(bytes(32), edPubKey.to_bytes())]

counter: int = 0
datas.append(Data(datas[0].hash, counter.to_bytes(4, byteorder="little")))
while (
  Sketch.hash(bytes(4), VerificationPacket(datas[0].hash, [0])) <= Sketch.hash(
    bytes(4),
    VerificationPacket(datas[1].hash, [0])
  )
):
  counter += 1
  datas[1] = Data(datas[0].hash, counter.to_bytes(4, byteorder="little"))

proto.add(packets=[VerificationPacket(datas[1].hash, [0]), VerificationPacket(datas[0].hash, [0])])

transactions: Transactions = Transactions()
for data in datas:
  data.sign(edPrivKey)
  transactions.add(data)

vectors: IO[Any] = open("e2e/Vectors/Merit/OutOfOrder/Packets.json", "w")
vectors.write(json.dumps({
  "blockchain": proto.toJSON(),
  "transactions": transactions.toJSON()
}))
vectors.close()
