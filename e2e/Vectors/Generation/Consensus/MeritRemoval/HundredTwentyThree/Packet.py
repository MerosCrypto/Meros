from typing import Dict, List, IO, Any
import json

import ed25519
from e2e.Libs.BLS import PrivateKey, PublicKey, Signature

from e2e.Classes.Transactions.Data import Data

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import SignedVerificationPacket, SignedMeritRemovalVerificationPacket
from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval
from e2e.Classes.Consensus.SpamFilter import SpamFilter

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

blsPrivKey: PrivateKey = PrivateKey(0)
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

spamFilter: SpamFilter = SpamFilter(5)

packetedChain: Blockchain = Blockchain()
reorderedChain: Blockchain = Blockchain()

#Generate a Block granting the holder Merit.
block = Block(
  BlockHeader(
    0,
    packetedChain.last(),
    bytes(32),
    1,
    bytes(4),
    bytes(32),
    blsPubKey.serialize(),
    packetedChain.blocks[-1].header.time + 1200
  ),
  BlockBody()
)
block.mine(blsPrivKey, packetedChain.difficulty())
packetedChain.add(block)
reorderedChain.add(block)
print("Generated Hundred Twenty Three Packet Block 1/2 " + str(len(packetedChain.blocks)) + ".")

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

#Generate a Block containing the MeritRemoval.
block = Block(
  BlockHeader(
    0,
    packetedChain.last(),
    BlockHeader.createContents([], [mr]),
    1,
    bytes(4),
    bytes(32),
    0,
    packetedChain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [mr], mr.signature)
)
block.mine(blsPrivKey, packetedChain.difficulty())
packetedChain.add(block)
print("Generated Hundred Twenty Three Packet Block 1 " + str(len(packetedChain.blocks)) + ".")

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

#Generate a Block containing the repeat MeritRemoval.
block = Block(
  BlockHeader(
    0,
    packetedChain.last(),
    BlockHeader.createContents([], [packeted]),
    1,
    bytes(4),
    bytes(32),
    0,
    packetedChain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [packeted], packeted.signature)
)
block.mine(blsPrivKey, packetedChain.difficulty())
packetedChain.add(block)
print("Generated Hundred Twenty Three Packet Block 1 " + str(len(packetedChain.blocks)) + ".")

#Generate a Block containing the packeted MeritRemoval.
block = Block(
  BlockHeader(
    0,
    reorderedChain.last(),
    BlockHeader.createContents([], [packeted]),
    1,
    bytes(4),
    bytes(32),
    0,
    reorderedChain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [packeted], packeted.signature)
)
block.mine(blsPrivKey, reorderedChain.difficulty())
reorderedChain.add(block)
print("Generated Hundred Twenty Three Packet Block 2 " + str(len(reorderedChain.blocks)) + ".")

#Recreate the MeritRemoval with reordered keys.
reordered: SignedMeritRemoval = SignedMeritRemoval(
  SignedMeritRemovalVerificationPacket(
    SignedVerificationPacket(verifs[1].hash),
    [
      blsPubKey.serialize(),
      PrivateKey(1).toPublicKey().serialize(),
      PrivateKey(2).toPublicKey().serialize()
    ],
    Signature.aggregate(
      [
        blsPrivKey.sign(verifs[1].signatureSerialize()),
        PrivateKey(1).sign(verifs[1].signatureSerialize()),
        PrivateKey(2).sign(verifs[1].signatureSerialize())
      ]
    )
  ),
  SignedMeritRemovalVerificationPacket(
    SignedVerificationPacket(verifs[2].hash),
    [
      PrivateKey(3).toPublicKey().serialize(),
      blsPubKey.serialize(),
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

#Generate a Block containing the reordered MeritRemoval.
block = Block(
  BlockHeader(
    0,
    reorderedChain.last(),
    BlockHeader.createContents([], [reordered]),
    1,
    bytes(4),
    bytes(32),
    0,
    reorderedChain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [reordered], reordered.signature)
)
block.mine(blsPrivKey, reorderedChain.difficulty())
reorderedChain.add(block)
print("Generated Hundred Twenty Three Packet Block 2 " + str(len(reorderedChain.blocks)) + ".")

result: Dict[str, Any] = {
  "blockchains": [packetedChain.toJSON(), reorderedChain.toJSON()],
  "datas": [datas[0].toJSON(), datas[1].toJSON(), datas[2].toJSON()],
  "removals": [mr.toSignedJSON(), packeted.toSignedJSON()]
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/HundredTwentyThree/Packet.json", "w")
vectors.write(json.dumps(result))
vectors.close()
