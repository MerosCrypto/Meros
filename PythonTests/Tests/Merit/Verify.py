#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#RPC class.
from PythonTests.Meros.RPC import RPC

#Sleep standard function.
from time import sleep

#Verify the Blockchain.
def verifyBlockchain(
  rpc: RPC,
  blockchain: Blockchain
) -> None:
  #Sleep to ensure data races aren't a problem.
  sleep(2)

  #Verify the height.
  if rpc.call("merit", "getHeight") != len(blockchain.blocks):
    raise TestError("Height doesn't match.")

  #Verify the difficulty.
  if blockchain.difficulty() != int(rpc.call("merit", "getDifficulty"), 16):
    raise TestError("Difficulty doesn't match.")

  #Verify the Blocks.
  for b in range(len(blockchain.blocks)):
    if rpc.call("merit", "getBlock", [b]) != blockchain.blocks[b].toJSON():
      raise TestError("Block doesn't match.")

    if rpc.call(
      "merit",
      "getBlock",
      [blockchain.blocks[b].header.hash.hex().upper()]
    ) != blockchain.blocks[b].toJSON():
      raise TestError("Block doesn't match.")
