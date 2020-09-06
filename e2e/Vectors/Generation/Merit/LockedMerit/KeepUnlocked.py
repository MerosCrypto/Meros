import json

from e2e.Classes.Consensus.DataDifficulty import DataDifficulty

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

keepsUnlockedViaElements: PrototypeChain = PrototypeChain(1, False)
for b in range(24):
  keepsUnlockedViaElements.add(elements=[DataDifficulty(b, b, 0)])

with open("e2e/Vectors/Merit/LockedMerit/KeepUnlocked.json", "w") as vectors:
  vectors.write(json.dumps([
    PrototypeChain(25).toJSON(),
    keepsUnlockedViaElements.toJSON()
  ]))
