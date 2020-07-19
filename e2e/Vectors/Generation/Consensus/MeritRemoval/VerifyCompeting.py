from typing import Dict, List, IO, Any
import json

import ed25519
from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
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
packets: List[VerificationPacket] = []
for data in datas:
  verifs.append(SignedVerification(data.hash, 0))
  verifs[-1].sign(0, blsPrivKey)
  packets.append(VerificationPacket(data.hash, [0]))

#Create a MeritRemoval out of the conflicting Verifications.
mr: SignedMeritRemoval = SignedMeritRemoval(verifs[1], verifs[2])

#Generate a Block containing the MeritRemoval.
proto.add(packets=packets, elements=[mr])

result: Dict[str, Any] = {
  "blockchain": proto.toJSON(),
  "datas": [datas[0].toJSON(), datas[1].toJSON(), datas[2].toJSON()],
  "verification": verifs[0].toSignedJSON(),
  "removal": mr.toSignedJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/VerifyCompeting.json", "w")
vectors.write(json.dumps(result))
vectors.close()
