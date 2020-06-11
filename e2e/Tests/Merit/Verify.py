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
  elif blockchain.difficulty() != int(rpc.call("merit", "getDifficulty"), 16):
    raise TestError("Difficulty doesn't match.")

  for b in range(len(blockchain.blocks)):
    if rpc.call("merit", "getBlock", [b]) != blockchain.blocks[b].toJSON():
      raise TestError("Block doesn't match.")
    elif rpc.call(
      "merit",
      "getBlock",
      [blockchain.blocks[b].header.hash.hex().upper()]
    ) != blockchain.blocks[b].toJSON():
      raise TestError("Block doesn't match.")
