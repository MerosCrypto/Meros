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
    ourBlock: Dict[str, Any] = blockchain.blocks[b].toJSON()
    #Info Python saves so it can properly load from the vectors yet the Meros RPC excludes.
    del ourBlock["header"]["packets"]

    blockJSON: Dict[str, Any] = rpc.call("merit", "getBlock", {"id": b})
    #Contextual info Python doesn't track.
    del blockJSON["removals"]
    if blockJSON != ourBlock:
      raise TestError("Block doesn't match.")

    #Test when indexing by the hash instead of the nonce.
    blockJSON = rpc.call(
      "merit",
      "getBlock",
      {"id": blockchain.blocks[b].header.hash.hex().upper()}
    )
    del blockJSON["removals"]
    if blockJSON != ourBlock:
      raise TestError("Block doesn't match.")
