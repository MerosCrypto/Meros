from typing import Dict, List, Any
import json

import e2e.Libs.Ristretto.ed25519 as ed25519

from e2e.Libs.BLS import PrivateKey

from e2e.Classes.Merit.Merit import Merit
from e2e.Classes.Consensus.SpamFilter import SpamFilter
from e2e.Classes.Transactions.Transactions import Claim, Send, Data

from e2e.Meros.RPC import RPC
from e2e.Meros.Meros import MessageType
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def TwoHundredFifteenTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Transactions/ClaimedMint.json", "r") as file:
    vectors = json.loads(file.read())

  merit: Merit = Merit.fromJSON(vectors["blockchain"])
  sendFilter: SpamFilter = SpamFilter(3)
  dataFilter: SpamFilter = SpamFilter(5)

  privKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
  pubKey: bytes = privKey.get_verifying_key()

  def syncUnknown() -> None:
    claim: Claim = Claim([(merit.mints[0], 0)], pubKey)
    claim.sign(PrivateKey(0))

    #Create a series of Sends, forming a diamond.
    #Cross sendB and sendC to actually force this to work in an ordered fashion to pass.
    sendA: Send = Send(
      [(claim.hash, 0)],
      [(pubKey, claim.amount // 2), (pubKey, claim.amount // 2)]
    )
    sendB: Send = Send(
      [(sendA.hash, 0)],
      [(pubKey, sendA.outputs[0][1] // 2), (pubKey, sendA.outputs[0][1] // 2)]
    )
    sendC: Send = Send(
      [(sendA.hash, 1), (sendB.hash, 1)],
      [(pubKey, sendA.outputs[1][1] + sendB.outputs[1][1])]
    )
    sendD: Send = Send(
      [(sendB.hash, 0), (sendC.hash, 0)],
      [(pubKey, claim.amount)]
    )
    for send in [sendA, sendB, sendC, sendD]:
      send.sign(privKey)
      send.beat(sendFilter)

    #Send the tail of the diamond, which should cause an ordered top-down sync.
    sent: bytes = rpc.meros.liveTransaction(sendD)
    for tx in [sendC, sendB, sendA, claim, sendA, claim, sendB, sendA, claim]:
      if rpc.meros.sync.recv() != (MessageType.TransactionRequest.toByte() + tx.hash):
        raise TestError("Meros didn't request one of the inputs.")
      rpc.meros.syncTransaction(tx)
    if rpc.meros.live.recv() != sent:
      raise TestError("Meros didn't broadcast the Send.")

    #Do the same for a few Data Transactions.
    datas: List[Data] = [Data(bytes(32), pubKey)]
    datas.append(Data(datas[-1].hash, bytes(1)))
    datas.append(Data(datas[-1].hash, bytes(1)))
    for data in datas:
      data.sign(privKey)
      data.beat(dataFilter)

  Liver(rpc, vectors["blockchain"], callbacks={7: syncUnknown}).live()
