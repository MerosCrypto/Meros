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

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

blsPrivKey: PrivateKey = PrivateKey(0)
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

spamFilter: SpamFilter = SpamFilter(5)

packetedChain: PrototypeChain = PrototypeChain(1, False)
reorderedChain: PrototypeChain = PrototypeChain(1, False)

#Create the initial Data and two competing Datas.
datas: List[Data] = [Data(bytes(32), edPubKey.to_bytes())]
datas.append(Data(datas[0].hash, b"Initial Data."))
datas.append(Data(datas[0].hash, b"Second Data."))
for data in datas:
  data.sign(edPrivKey)
  data.beat(spamFilter)

#Create Verifications for the competing Datas.
verifs: List[SignedVerification] = []
for d in range(1, len(datas)):
  verifs.append(SignedVerification(datas[d].hash, 0))
  verifs[-1].sign(0, blsPrivKey)

#Create a MeritRemoval out of the conflicting Verifications.
mr: SignedMeritRemoval = SignedMeritRemoval(verifs[0], verifs[1])

#Generate a Block containing the MeritRemoval.
packetedChain.add(elements=[mr])

#Create a MeritRemoval with random keys added in.
packeted: SignedMeritRemoval = SignedMeritRemoval(
  SignedMeritRemovalVerificationPacket(
    SignedVerificationPacket(verifs[0].hash),
    [
      blsPubKey.serialize(),
      PrivateKey(1).toPublicKey().serialize(),
      PrivateKey(2).toPublicKey().serialize()
    ],
    Signature.aggregate([
      blsPrivKey.sign(verifs[0].signatureSerialize()),
      PrivateKey(1).sign(verifs[0].signatureSerialize()),
      PrivateKey(2).sign(verifs[0].signatureSerialize())
    ])
  ),
  SignedMeritRemovalVerificationPacket(
    SignedVerificationPacket(verifs[1].hash),
    [
      blsPubKey.serialize(),
      PrivateKey(3).toPublicKey().serialize(),
      PrivateKey(4).toPublicKey().serialize()
    ],
    Signature.aggregate(
      [
        blsPrivKey.sign(verifs[1].signatureSerialize()),
        PrivateKey(3).sign(verifs[1].signatureSerialize()),
        PrivateKey(4).sign(verifs[1].signatureSerialize())
      ]
    )
  ),
  0
)

#Add the packeted MeritRemoval to both chains.
#Packeted already has the Verification and verifies packeting it doesn't identify as a new MeritRemoval.
#Reordered has this packeted MR, and another one, and verifies reordered participants doesn't identify as a new MeritRemoval.
packetedChain.add(elements=[packeted])
reorderedChain.add(elements=[packeted])

#Recreate the packeted MeritRemoval with reordered keys.
reordered: SignedMeritRemoval = SignedMeritRemoval(
  SignedMeritRemovalVerificationPacket(
    SignedVerificationPacket(verifs[0].hash),
    [
      blsPubKey.serialize(),
      PrivateKey(1).toPublicKey().serialize(),
      PrivateKey(2).toPublicKey().serialize()
    ],
    packeted.se1.signature
  ),
  SignedMeritRemovalVerificationPacket(
    SignedVerificationPacket(verifs[1].hash),
    [
      PrivateKey(3).toPublicKey().serialize(),
      blsPubKey.serialize(),
      PrivateKey(4).toPublicKey().serialize()
    ],
    packeted.se2.signature
  ),
  0
)
reorderedChain.add(elements=[reordered])

with open("e2e/Vectors/Consensus/MeritRemoval/HundredTwentyThree/Packet.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchains": [packetedChain.toJSON(), reorderedChain.toJSON()],
    "datas": [data.toJSON() for data in datas],
    "removals": [mr.toSignedJSON(), packeted.toSignedJSON()]
  }))
