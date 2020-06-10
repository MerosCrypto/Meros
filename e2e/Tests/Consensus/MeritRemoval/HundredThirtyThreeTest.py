#https://github.com/MerosCrypto/Meros/issues/133.

import pytest

#Types.
from typing import Dict, List, IO, Any

#Transactions classes.
from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Transactions.Transactions import Transactions

#Merit classes.
from e2e.Classes.Merit.Block import Block

#Meros classes.
from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

#TestError and SuccessError Exceptions.
from e2e.Tests.Errors import TestError, SuccessError

#Sleep standard function.
from time import sleep

#JSON standard lib.
import json

def HundredThirtyThreeTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/HundredThirtyThree.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  file.close()

  #Datas.
  datas: List[Data] = [
    Data.fromJSON(vectors["datas"][0]),
    Data.fromJSON(vectors["datas"][1]),
    Data.fromJSON(vectors["datas"][2])
  ]

  #Transactions.
  transactions: Transactions = Transactions()
  for data in datas:
    transactions.add(data)

  def testBlockchain(
    i: int
  ) -> None:
    def sendMeritRemoval() -> None:
      #Send the Datas.
      for data in datas:
        if rpc.meros.liveTransaction(data) != rpc.meros.live.recv():
          raise TestError("Meros didn't send us the Data.")

      #Send the Block containing the modified Merit Removal.
      block: Block = Block.fromJSON(vectors["blockchains"][i][-1])
      rpc.meros.liveBlockHeader(block.header)

      #Flag of if the Block's Body synced.
      blockBodySynced: bool = False

      #Handle sync requests.
      reqHash: bytes = bytes()
      while True:
        if blockBodySynced:
          #Sleep for a second so Meros handles the Block.
          sleep(1)

          #Try receiving from the Live socket, where Meros sends keep-alives.
          try:
            if len(rpc.meros.live.recv()) != 0:
              raise Exception()
          except TestError:
            #Verify the height is 2.
            #The genesis Block and the Block granting Merit.
            try:
              if rpc.call("merit", "getHeight") != 2:
                raise Exception()
            except Exception:
              raise TestError("Node added a Block containg a repeat MeritRemoval.")

            #Since the node didn't add the Block, raise SuccessError.
            raise SuccessError("Node didn't add a Block containing a repeat MeritRemoval.")
          except Exception:
            raise TestError("Meros sent a keep-alive.")

        msg: bytes = rpc.meros.sync.recv()
        if MessageType(msg[0]) == MessageType.BlockBodyRequest:
          reqHash = msg[1 : 33]
          if reqHash != block.header.hash:
            raise TestError("Meros asked for a Block Body that didn't belong to the Block we just sent it.")

          #Send the BlockBody.
          blockBodySynced = True
          rpc.meros.blockBody(block)

        else:
          raise TestError("Unexpected message sent: " + msg.hex().upper())

    Liver(
      rpc,
      vectors["blockchains"][i],
      transactions,
      callbacks={
        1: sendMeritRemoval
      }
    ).live()

  with pytest.raises(SuccessError):
    for b in range(2):
      testBlockchain(b)
