#https://github.com/MerosCrypto/Meros/issues/123.
#Tests that a MeritRemoval which has its Elements swapped and is sent again is rejected.

from typing import Dict, List, Any
from time import sleep
import json

from pytest import raises

from e2e.Classes.Merit.Block import Block

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError, SuccessError

def HTTSwapTest(
  rpc: RPC
) -> None:
  vectors: List[Dict[str, Any]]
  with open("e2e/Vectors/Consensus/MeritRemoval/HundredTwentyThree/Swap.json", "r") as file:
    vectors = json.loads(file.read())

  def sendRepeatMeritRemoval() -> None:
    #Send the Block containing the modified Merit Removal.
    block: Block = Block.fromJSON(vectors[-1])
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
          #Verify the height is 3.
          #The genesis Block, the Block granting Merit, and the Block containing the MeritRemoval originally.
          try:
            if rpc.call("merit", "getHeight") != 3:
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

  with raises(SuccessError):
    Liver(
      rpc,
      vectors,
      callbacks={
        2: sendRepeatMeritRemoval
      }
    ).live()
