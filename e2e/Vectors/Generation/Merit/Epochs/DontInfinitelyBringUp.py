from typing import List
import json

from e2e.Libs.BLS import PrivateKey
import e2e.Libs.Ristretto.Ristretto as Ristretto

from e2e.Classes.Transactions.Transactions import Data, Transactions

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.Merit import Block, Merit

from e2e.Vectors.Generation.PrototypeChain import PrototypeBlock, PrototypeChain

edPrivKey: Ristretto.SigningKey = Ristretto.SigningKey(b'\0' * 32)
edPubKey: bytes = edPrivKey.get_verifying_key()

transactions: Transactions = Transactions()
datas: List[Data] = [Data(bytes(32), edPubKey)]
for i in range(3):
  datas.append(Data(datas[0].hash, i.to_bytes(1, "little")))
datas[-1].beat(SpamFilter(5))
for d in range(len(datas)):
  datas[d].sign(edPrivKey)
  if d != 3:
    transactions.add(datas[d])

proto: PrototypeChain = PrototypeChain(1, keepUnlocked=True)
proto.add(packets=[VerificationPacket(datas[0].hash, [0]), VerificationPacket(datas[1].hash, [0])])
for i in range(4):
  #We only need 1/2.
  proto.add(i % 3)
#Bring up the TX.
proto.add(packets=[VerificationPacket(datas[2].hash, [1])])

#Create a Verification for the final competitor in order to test template behavior as well.
verif: SignedVerification = SignedVerification(datas[3].hash, 2)
verif.sign(2, PrivateKey(3))

#Convert to Merit in order to create an alternate Block which attempts to further bring up the TX in question.
merit: Merit = Merit.fromJSON(proto.toJSON())
#Alternate Block (invalid).
alt: Block = PrototypeBlock(
  merit.blockchain.blocks[-1].header.time + 1200,
  [VerificationPacket(datas[3].hash, [2])]
).finish(0, merit)

#Finalize everything.
for _ in range(5):
  merit.add(PrototypeBlock(merit.blockchain.blocks[-1].header.time + 1200).finish(0, merit))

with open("e2e/Vectors/Merit/Epochs/DontInfinitelyBringUp.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": merit.toJSON(),
    "transactions": transactions.toJSON(),
    "datas": [datas[1].toJSON(), datas[3].toJSON()],
    "verification": verif.toSignedJSON(),
    "bringUpBlock": alt.toJSON()
  }))
