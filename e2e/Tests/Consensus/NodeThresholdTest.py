from typing import List
import json

import e2e.Libs.Ristretto.Ristretto as Ristretto

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def NodeThresholdTest(
  rpc: RPC
) -> None:
  edPrivKey: Ristretto.SigningKey = Ristretto.SigningKey(b'\0' * 32)

  dataFilter: SpamFilter = SpamFilter(5)

  datas: List[Data] = [Data(bytes(32), edPrivKey.get_verifying_key())]
  datas[-1].sign(edPrivKey)
  datas[-1].beat(dataFilter)

  def verifyThreshold(
    b: int
  ) -> None:
    rpc.meros.liveTransaction(datas[-1])
    datas.append(Data(datas[-1].hash, b"a"))
    datas[-1].sign(edPrivKey)
    datas[-1].beat(dataFilter)

    #Swallow the new Data(s).
    if b == 1:
      rpc.meros.live.recv()
    rpc.meros.live.recv()

    #Check the threshold.
    threshold: int = rpc.call("consensus", "getStatus", {"hash": datas[-2].hash.hex()})["threshold"]
    if b < 9:
      if threshold != ((max(b + 6, 5) // 5 * 4) + 1):
        raise TestError("Meros didn't calculate the right node threshold. That said, this isn't defined by the protocol.")
    elif threshold != 5:
      raise TestError("Meros didn't lower the node threshold.")

  with open("e2e/Vectors/Merit/BlankBlocks.json", "r") as file:
    Liver(rpc, json.loads(file.read())[:9], everyBlock=verifyThreshold).live()
