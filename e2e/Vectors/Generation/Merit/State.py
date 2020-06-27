from typing import IO, Any
from random import seed, getrandbits
import json

from e2e.Classes.Merit.State import State

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

#Ensure consistent vectors.
seed(1)

chain: PrototypeChain = PrototypeChain(1)
miners: int = 1

#State is used solely to get the lifetime.
#This test only has significance when Dead Merit is also tested.
for _ in range(State().lifetime * 3):
  #Why manually specify hundreds of miners when we can randomize it?
  nextMiner: int = getrandbits(8) % miners
  #If the nextMiner is 0, it's either trying to use the original miner or a new miner.
  #Create a 50% chance of creating a new miner.
  if (nextMiner == 0) and (getrandbits(1) == 1):
    nextMiner = miners
  chain.add(nextMiner)

vectors: IO[Any] = open("e2e/Vectors/Merit/State.json", "w")
vectors.write(json.dumps(chain.toJSON()))
vectors.close()
