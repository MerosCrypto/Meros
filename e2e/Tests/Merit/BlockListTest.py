#Tests proper inclusion of headers in BlockListRequest response with varying lengths.
from typing import Dict, List, Any
import json

from e2e.Classes.Merit.Blockchain import Blockchain
from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver
from e2e.Tests.Errors import TestError

def BlockListTest(
  rpc: RPC
) -> None:
  with open("e2e/Vectors/Merit/BlankBlocks.json", "r") as file:
    vectors: List[Dict[str, Any]] = json.loads(file.read())
  chain: Blockchain = Blockchain.fromJSON(vectors)

  amount1: int = 25
  amount2: int = 6
  def constructResponse(
    amount: int,
    lastBlock: int = -1
  ) -> bytes:
    if lastBlock == -1:
      lastBlock = len(chain.blocks)
    lastBlock = min(amount, lastBlock)
    quantity: bytes = (lastBlock - 1).to_bytes(1, byteorder="little")
    hashes: List[bytes] = [block.header.hash for block in chain.blocks[:lastBlock]]
    return quantity + b"".join(reversed(hashes))

  def beforeGenesis() -> None:
    rpc.meros.blockListRequest(1, chain.blocks[0].header.hash)
    blockList: bytes = rpc.meros.sync.recv()
    if blockList != MessageType.DataMissing.toByte():
      raise TestError("Meros did not return a DataMissing response to a BlockListRequest of the Block before genesis.")

  def lessThanRequested() -> None:
    rpc.meros.blockListRequest(amount2, chain.blocks[amount2 - 1].header.hash)
    blockList: bytes = rpc.meros.sync.recv()
    if blockList[1:] != constructResponse(amount1, amount2 - 1):
      raise TestError("Meros didn't properly return fewer blocks when a BlockListRequest requests more blocks than exist.")
    if (len(blockList[2:]) / 32) != (amount2 - 1):
      raise Exception("Testing methodology error; considered the right amount of Blocks valid (not less than requested).")

  def recHash() -> None:
    rpc.meros.blockListRequest(amount1, chain.blocks[amount1].header.hash)
    blockList: bytes = rpc.meros.sync.recv()
    if blockList[1:] != constructResponse(amount1):
      raise TestError("Meros returned a different BlockList than expected in response to a BlockListRequest.")

  Liver(
    rpc,
    vectors,
    callbacks={
      1: beforeGenesis,
      (amount2 - 1): lessThanRequested,
      amount1: recHash
    }
  ).live()
