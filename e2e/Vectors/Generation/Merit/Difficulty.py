from random import seed, getrandbits
import json

from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

#Ensure consistent vectors.
seed(1)

chain: PrototypeChain = PrototypeChain(keepUnlocked=False)

blockTime: int = Blockchain().blockTime
for _ in range(100):
  #Change the time offset to ensure quality difficulty calculation..
  chain.timeOffset = max(getrandbits(32) % (blockTime * 3), blockTime // 2)
  chain.add()

with open("e2e/Vectors/Merit/Difficulty.json", "w") as vectors:
  vectors.write(json.dumps(chain.toJSON()))
