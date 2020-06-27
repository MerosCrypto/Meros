from typing import Dict, List, IO, Any
import json

from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty
from e2e.Classes.Consensus.MeritRemoval import PartialMeritRemoval, SignedMeritRemoval

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

blsPrivKey: PrivateKey = PrivateKey(0)
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

blockchain: PrototypeChain = PrototypeChain(1, False)

#Create conflicting Data Difficulties.
dataDiffs: List[SignedDataDifficulty] = [
  SignedDataDifficulty(3, 0),
  SignedDataDifficulty(4, 0)
]
dataDiffs[0].sign(0, blsPrivKey)
dataDiffs[1].sign(0, blsPrivKey)

#Generate a Block containing the first Data Difficulty.
blockchain.add(elements=[dataDiffs[0]])

#Create a partial MeritRemoval out of the conflicting Data Difficulties.
partial: PartialMeritRemoval = PartialMeritRemoval(dataDiffs[0], dataDiffs[1])
blockchain.add(elements=[partial])

#Create a MeritRemoval which isn't partial.
mr: SignedMeritRemoval = SignedMeritRemoval(dataDiffs[0], dataDiffs[1])
blockchain.add(elements=[mr])

result: Dict[str, Any] = {
  "blockchain": blockchain.finish().toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/HundredTwentyThree/Partial.json", "w")
vectors.write(json.dumps(result))
vectors.close()
