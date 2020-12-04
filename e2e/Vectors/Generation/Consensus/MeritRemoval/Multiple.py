import json

from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty
from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

proto: PrototypeChain = PrototypeChain(1, False)

blsPrivKey: PrivateKey = PrivateKey(0)
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Create a DataDifficulty.
dataDiff: SignedDataDifficulty = SignedDataDifficulty(3, 0)
dataDiff.sign(0, blsPrivKey)

#Create a conflicting DataDifficulty with the same nonce.
dataDiffConflicting: SignedDataDifficulty = SignedDataDifficulty(1, 0)
dataDiffConflicting.sign(0, blsPrivKey)

#Create a MeritRemoval out of the two of them.
mr1: SignedMeritRemoval = SignedMeritRemoval(dataDiff, dataDiffConflicting)
proto.add(elements=[dataDiff, dataDiffConflicting])

#Create two more DataDifficulties with a different nonce.
dataDiff = SignedDataDifficulty(3, 1)
dataDiff.sign(0, blsPrivKey)
dataDiffConflicting = SignedDataDifficulty(1, 1)
dataDiffConflicting.sign(0, blsPrivKey)

#Create another MeritRemoval out of these two.
mr2: SignedMeritRemoval = SignedMeritRemoval(dataDiff, dataDiffConflicting)

with open("e2e/Vectors/Consensus/MeritRemoval/Multiple.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": proto.toJSON(),
    "removals": [mr1.toSignedJSON(), mr2.toSignedJSON()]
  }))
