import json

import ed25519

from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import SignedVerificationPacket, SignedMeritRemovalVerificationPacket
from e2e.Classes.Consensus.SendDifficulty import SignedSendDifficulty
from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty
from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

proto: PrototypeChain = PrototypeChain(1, False)

blsPrivKey: PrivateKey = PrivateKey(0)
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#Create the SendDifficulty MR.
sendDiff: SignedSendDifficulty = SignedSendDifficulty(4, 0)
sendDiff.sign(0, blsPrivKey)
sendDiffMR: SignedMeritRemoval = SignedMeritRemoval(sendDiff, sendDiff)

#Create the DataDifficulty MR.
dataDiff: SignedDataDifficulty = SignedDataDifficulty(4, 0)
dataDiff.sign(0, blsPrivKey)
dataDiffMR: SignedMeritRemoval = SignedMeritRemoval(dataDiff, dataDiff)

#Create the Verification MR.
data: Data = Data(bytes(32), edPubKey.to_bytes())
data.sign(edPrivKey)
data.beat(SpamFilter(5))
verif: SignedVerification = SignedVerification(data.hash)
verif.sign(0, blsPrivKey)

#Transform the Verification to a SignedMeritRemovalVerificationPacket.
packet: SignedMeritRemovalVerificationPacket = SignedMeritRemovalVerificationPacket(
  SignedVerificationPacket(data.hash),
  [blsPubKey.serialize()],
  verif.signature
)
verifMR: SignedMeritRemoval = SignedMeritRemoval(verif, packet)

with open("e2e/Vectors/Consensus/MeritRemoval/SameElement.json", "w") as vectors:
  vectors.write(
    json.dumps(
      {
        "blockchain": proto.toJSON(),
        "removals": [
          sendDiffMR.toSignedJSON(),
          dataDiffMR.toSignedJSON(),
          verifMR.toSignedJSON()
        ],
        "data": data.toJSON()
      }
    )
  )
