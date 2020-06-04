#Types.
from typing import Dict, List, IO, Any

#BLS lib.
from e2e.Libs.BLS import PrivateKey, PublicKey

#Data class.
from e2e.Classes.Transactions.Data import Data

#Element classes.
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import SignedVerificationPacket, SignedMeritRemovalVerificationPacket
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

#Ed25519 Keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#BLS Keys.
blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

#SpamFilter.
spamFilter: SpamFilter = SpamFilter(5)

#Blockchains.
e1Chain: Blockchain = Blockchain()
e2Chain: Blockchain = Blockchain()

#Generate a Block granting the holder Merit.
block = Block(
  BlockHeader(
    0,
    e1Chain.last(),
    bytes(32),
    1,
    bytes(4),
    bytes(32),
    blsPubKey.serialize(),
    e1Chain.blocks[-1].header.time + 1200
  ),
  BlockBody()
)
#Mine it.
block.mine(blsPrivKey, e1Chain.difficulty())

#Add it.
e1Chain.add(block)
e2Chain.add(block)
print("Generated Hundred Thirty Three Block 1/2 " + str(len(e1Chain.blocks)) + ".")

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
    [
      PrivateKey(blake2b(b'\1', digest_size=32).digest()).toPublicKey().serialize()
    ],
    PrivateKey(blake2b(b'\1', digest_size=32).digest()).sign(verifs[1].signatureSerialize())
  ),
  SignedMeritRemovalVerificationPacket(
    SignedVerificationPacket(verifs[1].hash),
    [
      PrivateKey(blake2b(b'\1', digest_size=32).digest()).toPublicKey().serialize()
    ],
    PrivateKey(blake2b(b'\1', digest_size=32).digest()).sign(verifs[1].signatureSerialize())
  )
]

#Create a MeritRemoval out of the conflicting Verifications.
e1MR: SignedMeritRemoval = SignedMeritRemoval(verifs[1], packets[0], 0)
e2MR: SignedMeritRemoval = SignedMeritRemoval(packets[1], verifs[2], 0)

#Generate a Block containing the MeritRemoval for each chain.
block = Block(
  BlockHeader(
    0,
    e1Chain.last(),
    BlockHeader.createContents([], [e1MR]),
    1,
    bytes(4),
    bytes(32),
    0,
    e1Chain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [e1MR], e1MR.signature)
)
block.mine(blsPrivKey, e1Chain.difficulty())
e1Chain.add(block)
print("Generated Hundred Twenty Three Packet Block 1 " + str(len(e1Chain.blocks)) + ".")

block = Block(
  BlockHeader(
    0,
    e2Chain.last(),
    BlockHeader.createContents([], [e2MR]),
    1,
    bytes(4),
    bytes(32),
    0,
    e2Chain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [e2MR], e2MR.signature)
)
block.mine(blsPrivKey, e2Chain.difficulty())
e2Chain.add(block)
print("Generated Hundred Twenty Three Packet Block 2 " + str(len(e2Chain.blocks)) + ".")

result: Dict[str, Any] = {
  "blockchains": [e1Chain.toJSON(), e2Chain.toJSON()],
  "datas": [datas[0].toJSON(), datas[1].toJSON(), datas[2].toJSON()]
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/HundredThirtyThree.json", "w")
vectors.write(json.dumps(result))
vectors.close()
