from typing import Dict, Any
import json

from e2e.Classes.Merit.Block import Block
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

def RespondsWithRequestedCapacityTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Merit/TwoHundredSeventyFour/RespondsWithRequestedCapacity.json", "r") as file:
    vectors = json.loads(file.read())

  def requestWithCapacity() -> None:
    block: Block = Block.fromJSON(vectors["blockchain"][-1])

    #Request 3/6 Transactions.
    rpc.meros.sync.send(MessageType.BlockBodyRequest.toByte() + block.header.hash + (3).to_bytes(4, "little"))
    if rpc.meros.sync.recv() != (MessageType.BlockBody.toByte() + block.body.serialize(block.header.sketchSalt, 3)):
      raise TestError("Meros didn't respond with the requested capacity.")

    #Request 8/6 Transactions.
    rpc.meros.sync.send(MessageType.BlockBodyRequest.toByte() + block.header.hash + (8).to_bytes(4, "little"))
    if rpc.meros.sync.recv() != (MessageType.BlockBody.toByte() + block.body.serialize(block.header.sketchSalt, 6)):
      raise TestError("Meros didn't respond with the requested capacity (normalized).")

  Liver(
    rpc,
    vectors["blockchain"],
    Transactions.fromJSON(vectors["transactions"]),
    callbacks={
      2: requestWithCapacity
    }
  ).live()
