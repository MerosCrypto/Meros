from typing import Dict, IO, Any
import json

from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

proto: PrototypeChain = PrototypeChain(1, False)

blsPrivKey: PrivateKey = PrivateKey(0)
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Create a DataDifficulty.
dataDiff: SignedDataDifficulty = SignedDataDifficulty(3, 0)
dataDiff.sign(0, blsPrivKey)

#Create a conflicting DataDifficulty with the same nonce.
dataDiffConflicting = SignedDataDifficulty(1, 0)
dataDiffConflicting.sign(0, blsPrivKey)

#Generate a Block containing the competing Data difficulty.
proto.add(elements=[dataDiffConflicting])
result: Dict[str, Any] = {
  "blockchain": proto.toJSON(),
  "mempoolDataDiff": dataDiff.toSignedJSON(),
  "protoDataDiff": dataDiffConflicting.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/HundredTwenty.json", "w")
vectors.write(json.dumps(result))
vectors.close()
