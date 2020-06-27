from typing import Dict, List, IO, Any
import json

import ed25519

from e2e.Libs.BLS import PrivateKey, PublicKey

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

e1Chain: PrototypeChain = PrototypeChain(1, False)
e2Chain: PrototypeChain = PrototypeChain(1, False)

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

#Create a MeritRemoval VerificationPacket for the second and third Datas which don't involve our holder.
packets: List[SignedMeritRemovalVerificationPacket] = [
  SignedMeritRemovalVerificationPacket(
    SignedVerificationPacket(verifs[1].hash),
    [PrivateKey(1).toPublicKey().serialize()],
    PrivateKey(1).sign(verifs[1].signatureSerialize())
  ),
  SignedMeritRemovalVerificationPacket(
    SignedVerificationPacket(verifs[1].hash),
    [PrivateKey(1).toPublicKey().serialize()],
    PrivateKey(1).sign(verifs[1].signatureSerialize())
  )
]

#Create a MeritRemoval out of the conflicting Verifications.
e1MR: SignedMeritRemoval = SignedMeritRemoval(verifs[1], packets[0], 0)
e2MR: SignedMeritRemoval = SignedMeritRemoval(packets[1], verifs[2], 0)

#Generate a Block containing the MeritRemoval for each chain.
e1Chain.add(elements=[e1MR])
e2Chain.add(elements=[e2MR])

result: Dict[str, Any] = {
  "protos": [e1Chain.toJSON(), e2Chain.toJSON()],
  "datas": [datas[0].toJSON(), datas[1].toJSON(), datas[2].toJSON()]
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/HundredThirtyThree.json", "w")
vectors.write(json.dumps(result))
vectors.close()
