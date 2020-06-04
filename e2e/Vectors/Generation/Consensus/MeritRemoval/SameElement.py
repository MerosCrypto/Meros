#Types.
from typing import Dict, IO, Any

#BLS lib.
from e2e.Libs.BLS import PrivateKey, PublicKey

#Data class.
from e2e.Classes.Transactions.Data import Data

#Element classes.
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import SignedVerificationPacket, SignedMeritRemovalVerificationPacket
from e2e.Classes.Consensus.SendDifficulty import SignedSendDifficulty
from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty
from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval

#SpamFilter class.
from e2e.Classes.Consensus.SpamFilter import SpamFilter

#Blockchain classes.
from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

#Ed25519 lib.
import ed25519

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#Blockchain.
blockchain: Blockchain = Blockchain()

#BLS Keys.
blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#Ed25519 keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#Generate a Block granting the holder Merit.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    bytes(32),
    1,
    bytes(4),
    bytes(32),
    blsPubKey.serialize(),
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody()
)
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated Same Element Block " + str(len(blockchain.blocks)) + ".")

#Create a SendDifficulty.
sendDiff: SignedSendDifficulty = SignedSendDifficulty(4, 0)
sendDiff.sign(0, blsPrivKey)

#Create a DataDifficulty.
dataDiff: SignedDataDifficulty = SignedDataDifficulty(4, 0)
dataDiff.sign(0, blsPrivKey)

#Create a Data.
data: Data = Data(bytes(32), edPubKey.to_bytes())
data.sign(edPrivKey)
data.beat(SpamFilter(5))

#Create a Verification.
verif: SignedVerification = SignedVerification(data.hash)
verif.sign(0, blsPrivKey)

#Create a MeritRemovalVerificationPacket verifying the same Transaction as the Verification.
packet: SignedMeritRemovalVerificationPacket = SignedMeritRemovalVerificationPacket(
  SignedVerificationPacket(data.hash),
  [blsPubKey.serialize()],
  verif.signature
)

#Create the three MeritRemovals.
sendDiffMR: SignedMeritRemoval = SignedMeritRemoval(sendDiff, sendDiff)
dataDiffMR: SignedMeritRemoval = SignedMeritRemoval(dataDiff, dataDiff)
verifMR: SignedMeritRemoval = SignedMeritRemoval(verif, packet)

result: Dict[str, Any] = {
  "blockchain": blockchain.toJSON(),
  "removals": [
    sendDiffMR.toSignedJSON(),
    dataDiffMR.toSignedJSON(),
    verifMR.toSignedJSON()
  ],
  "data": data.toJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/SameElement.json", "w")
vectors.write(json.dumps(result))
vectors.close()
