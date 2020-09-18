import json

import ed25519
from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval

from e2e.Vectors.Generation.PrototypeChain import PrototypeChain

proto: PrototypeChain = PrototypeChain(1, False)
transactions: Transactions = Transactions()

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

blsPrivKey: PrivateKey = PrivateKey(0)
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Create a Data using a bogus input.
data: Data = Data(bytes.fromhex("11" * 32), bytes(1))
transactions.add(data)

#Create a competing Data using the same input.
competingData: Data = Data(bytes.fromhex("11" * 32), bytes(2))
transactions.add(competingData)

#Verify the Datas.
verif: SignedVerification = SignedVerification(data.hash)
verif.sign(0, blsPrivKey)

competingVerif: SignedVerification = SignedVerification(competingData.hash)
competingVerif.sign(0, blsPrivKey)

#Create a MeritRemoval out of the (meaningless0 conflicting Verifications.
mr: SignedMeritRemoval = SignedMeritRemoval(verif, competingVerif)
proto.add(elements=[mr])

with open("e2e/Vectors/Consensus/MeritRemoval/InvalidCompeting.json", "w") as vectors:
  vectors.write(json.dumps({
    "blockchain": proto.toJSON(),
    "transactions": transactions.toJSON(),
    "removal": mr.toSignedJSON()
  }))
