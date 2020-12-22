from typing import Dict, Any

from time import sleep

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.RPC import RPC

from e2e.Tests.Errors import TestError

def verifyBlockchain(
  rpc: RPC,
  blockchain: Blockchain
) -> None:
  sleep(2)

  if rpc.call("merit", "getHeight") != len(blockchain.blocks):
    raise TestError("Height doesn't match.")
  if blockchain.difficulty() != rpc.call("merit", "getDifficulty"):
    raise TestError("Difficulty doesn't match.")

  for b in range(len(blockchain.blocks)):
    blockJSON: Dict[str, Any] = rpc.call("merit", "getBlock", [b])
    del blockJSON["removals"]
    if blockJSON != blockchain.blocks[b].toJSON():
      raise TestError("Block doesn't match.")

    blockJSON = rpc.call(
      "merit",
      "getBlock",
      [blockchain.blocks[b].header.hash.hex().upper()]
    )
    #Contextual info Python doesn't track.
    del blockJSON["removals"]
    if blockJSON != blockchain.blocks[b].toJSON():
      raise TestError("Block doesn't match.")
