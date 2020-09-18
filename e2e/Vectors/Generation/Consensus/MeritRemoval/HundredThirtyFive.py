from typing import List
import json

import ed25519
from e2e.Libs.BLS import PrivateKey, PublicKey, Signature

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import SignedVerificationPacket, SignedMeritRemovalVerificationPacket
from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval

from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

proto: PrototypeChain = PrototypeChain(1, False)

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

blsPrivKey: PrivateKey = PrivateKey(0)
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

spamFilter: SpamFilter = SpamFilter(5)

#Create the initial Data and two competing Datas.
datas: List[Data] = [Data(bytes(32), edPubKey.to_bytes())]
datas.append(Data(datas[0].hash, b"Initial Data."))
datas.append(Data(datas[0].hash, b"Second Data."))
for data in datas:
  data.sign(edPrivKey)
  data.beat(spamFilter)

#Create Verifications for all 3.
verifs: List[SignedVerification] = []
for data in datas:
  verifs.append(SignedVerification(data.hash, 0))
  verifs[-1].sign(0, blsPrivKey)

#Create a MeritRemoval out of the conflicting Verifications.
mr: SignedMeritRemoval = SignedMeritRemoval(verifs[1], verifs[2])

#Create a MeritRemoval with random keys.
packeted: SignedMeritRemoval = SignedMeritRemoval(
  SignedMeritRemovalVerificationPacket(
    SignedVerificationPacket(verifs[1].hash),
    [
      blsPubKey.serialize(),
      PrivateKey(1).toPublicKey().serialize(),
      PrivateKey(2).toPublicKey().serialize()
    ],
    Signature.aggregate([
      blsPrivKey.sign(verifs[1].signatureSerialize()),
      PrivateKey(1).sign(verifs[1].signatureSerialize()),
      PrivateKey(2).sign(verifs[1].signatureSerialize())
    ])
  ),
  SignedMeritRemovalVerificationPacket(
    SignedVerificationPacket(verifs[2].hash),
    [
      blsPubKey.serialize(),
      PrivateKey(3).toPublicKey().serialize(),
      PrivateKey(4).toPublicKey().serialize()
    ],
    Signature.aggregate(
      [
        blsPrivKey.sign(verifs[2].signatureSerialize()),
        PrivateKey(3).sign(verifs[2].signatureSerialize()),
        PrivateKey(4).sign(verifs[2].signatureSerialize())
      ]
    )
  ),
  0
)

#Generate a Block containing the modified MeritRemoval.
proto.add(elements=[packeted])

with open("e2e/Vectors/Consensus/MeritRemoval/HundredThirtyFive.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": proto.toJSON(),
    "datas": [data.toJSON() for data in datas],
    "removal": mr.toSignedJSON()
  }))
