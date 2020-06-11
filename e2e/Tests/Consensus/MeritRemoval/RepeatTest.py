#Tests proper handling of a MeritRemoval which has already been archived.

from typing import Dict, List, IO, Any
import json

from raises

from e2e.Classes.Merit.Block import Block

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError, SuccessError

def RepeatTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/Repeat.json", "r")
  vectors: List[Dict[str, Any]] = json.loads(file.read())
  file.close()

  def sendBlock() -> None:
    #Send the Block with the MeritRemoval archived again.
    block: Block = Block.fromJSON(vectors[-1])
    rpc.meros.liveBlockHeader(block.header)

    #Flag of if the Block's Body synced.
    blockBodySynced: bool = False

    #Handle sync requests.
    reqHash: bytes = bytes()
    while True:
      if blockBodySynced:
        #Try receiving from the Live socket, where Meros sends keep-alives.
        try:
          if len(rpc.meros.live.recv()) != 0:
            raise Exception()
        except TestError:
          raise SuccessError("Meros didn't add the same MeritRemoval twice.")
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
        3: sendBlock
      }
    ).live()
