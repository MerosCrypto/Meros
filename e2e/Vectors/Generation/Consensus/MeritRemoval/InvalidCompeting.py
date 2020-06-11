from typing import Dict, IO, Any
from hashlib import blake2b
import json

import ed25519

from e2e.Libs.BLS import PrivateKey, PublicKey

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Transactions.Transactions import Transactions

from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.MeritRemoval import SignedMeritRemoval

from e2e.Classes.Merit.BlockHeader import BlockHeader
from e2e.Classes.Merit.BlockBody import BlockBody
from e2e.Classes.Merit.Block import Block
from e2e.Classes.Merit.Blockchain import Blockchain

transactions: Transactions = Transactions()
blockchain: Blockchain = Blockchain()

edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

blsPrivKey: PrivateKey = PrivateKey(blake2b(b'\0', digest_size=32).digest())
blsPubKey: PublicKey = blsPrivKey.toPublicKey()

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
block.mine(blsPrivKey, blockchain.difficulty())
blockchain.add(block)
print("Generated Invalid Competing Block " + str(len(blockchain.blocks)) + ".")

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

#Create a MeritRemoval out of the conflicting Verifications.
mr: SignedMeritRemoval = SignedMeritRemoval(verif, competingVerif)

#Generate a Block containing the MeritRemoval.
block = Block(
  BlockHeader(
    0,
    blockchain.last(),
    BlockHeader.createContents([], [mr]),
    1,
    bytes(4),
    BlockHeader.createSketchCheck(bytes(4), []),
    0,
    blockchain.blocks[-1].header.time + 1200
  ),
  BlockBody([], [mr], mr.signature)
)
block.mine(blsPrivKey, blockchain.difficulty())
blockchain.add(block)
print("Generated Invalid Competing Block " + str(len(blockchain.blocks)) + ".")

result: Dict[str, Any] = {
  "blockchain": blockchain.toJSON(),
  "transactions": transactions.toJSON(),
  "removal": mr.toSignedJSON()
}
vectors: IO[Any] = open("e2e/Vectors/Consensus/MeritRemoval/InvalidCompeting.json", "w")
vectors.write(json.dumps(result))
vectors.close()
