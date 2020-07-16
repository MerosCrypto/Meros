from typing import Dict, List, IO, Any
from time import sleep
import json

from pytest import raises

from e2e.Classes.Merit.Blockchain import Block, Blockchain

from e2e.Meros.Meros import MessageType, Meros

from e2e.Tests.Errors import TestError, SuccessError

def HundredEightySevenTest(
  meros: Meros
) -> None:
  file: IO[Any] = open("e2e/Vectors/Merit/HundredEightySeven.json", "r")
  vectors: List[Dict[str, Any]] = json.loads(file.read())
  file.close()

  meros.liveConnect(Blockchain().last())
  meros.syncConnect(Blockchain().last())

  block: Block = Block.fromJSON(vectors[0])
  sent: bytes = meros.liveBlockHeader(block.header)
  if meros.sync.recv() != MessageType.BlockBodyRequest.toByte() + block.header.hash:
    raise TestError("Meros didn't request the matching BlockBody.")
  meros.blockBody(block)
  if meros.live.recv() != sent:
    raise TestError("Meros didn't broadcast a BlockHeader.")

  meros.liveBlockHeader(Block.fromJSON(vectors[1]).header)
  with raises(SuccessError):
    try:
      if len(meros.live.recv()) != 0:
        raise Exception()
    except TestError:
      sleep(1)
      if meros.process.poll() is not None:
        raise TestError("Node crashed trying to handle a BlockHeader which re-registers a key.")
      raise SuccessError("Node disconnected us after we sent a BlockHeader which re-registers a key.")
    except Exception:
      raise TestError("Meros didn't disconnect us after we sent a BlockHeader which re-registers a key; it also didn't crash.")
