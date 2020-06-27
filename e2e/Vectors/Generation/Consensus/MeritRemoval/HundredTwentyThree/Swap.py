from typing import Dict, List, IO, Any
import json

from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty
from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

blsPrivKey: PrivateKey = PrivateKey(0)
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

proto: PrototypeChain = PrototypeChain(1, False)

#Create conflicting Data Difficulties.
dataDiffs: List[SignedDataDifficulty] = [
  SignedDataDifficulty(3, 0),
  SignedDataDifficulty(4, 0)
]
dataDiffs[0].sign(0, blsPrivKey)
dataDiffs[1].sign(0, blsPrivKey)

#Create a MeritRemoval out of the conflicting Data Difficulties.
mr: SignedMeritRemoval = SignedMeritRemoval(dataDiffs[0], dataDiffs[1])
proto.add(elements=[mr])

#Create a MeritRemoval with the Elements swapped.
swapped: SignedMeritRemoval = SignedMeritRemoval(dataDiffs[1], dataDiffs[0])
proto.add(elements=[swapped])

result: Dict[str, Any] = {
  "blockchain": proto.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/HundredTwentyThree/Swap.json", "w")
vectors.write(json.dumps(result))
vectors.close()
