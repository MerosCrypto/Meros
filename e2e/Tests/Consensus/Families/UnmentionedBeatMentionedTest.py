from typing import List

import ed25519
from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

dataFilter: SpamFilter = SpamFilter(5)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

proto: PrototypeChain = PrototypeChain(40, keepUnlocked=True)
proto.add(1)

datas: List[Data] = [Data(bytes(32), edPubKey.to_bytes())]
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

def UnmentionedBeatMentionedTest(
  rpc: RPC
) -> None:
  def sendDatas() -> None:
    for d in range(len(datas)):
      if rpc.meros.liveTransaction(datas[d]) != rpc.meros.live.recv():
        raise TestError("Meros didn't broadcast a Data.")

    #Might as well send this now.
    if rpc.meros.signedElement(verif) != rpc.meros.live.recv():
      raise TestError("Meros didn't broadcast the Verification.")

  def verifyMentionedWon() -> None:
    if not rpc.call("consensus", "getStatus", [datas[2].hash.hex()])["verified"]:
      raise TestError("Meros didn't verify the only Transaction on chain which has finalized.")

  Liver(
    rpc,
    proto.toJSON(),
    callbacks={
      41: sendDatas,
      47: verifyMentionedWon
    }
  ).live()

  raise TestError("Test is unfinished; inlines vector generation which causes them to be re-mined at runtime.")
