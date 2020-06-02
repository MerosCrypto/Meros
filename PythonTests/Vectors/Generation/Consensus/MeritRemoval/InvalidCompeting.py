#Types.
from typing import Dict, IO, Any

#BLS lib.
from PythonTests.Libs.BLS import PrivateKey, PublicKey

#Transactions classes.
from PythonTests.Classes.Transactions.Data import Data
from PythonTests.Classes.Transactions.Transactions import Transactions

#Element classes.
from PythonTests.Classes.Consensus.Verification import SignedVerification
from PythonTests.Classes.Consensus.MeritRemoval import SignedMeritRemoval

#Blockchain classes.
from PythonTests.Classes.Merit.BlockHeader import BlockHeader
from PythonTests.Classes.Merit.BlockBody import BlockBody
from PythonTests.Classes.Merit.Block import Block
from PythonTests.Classes.Merit.Blockchain import Blockchain

#Ed25519 lib.
import ed25519

#Blake2b standard function.
from hashlib import blake2b

#JSON standard lib.
import json

#Transactions.
transactions: Transactions = Transactions()
#Blockchain.
blockchain: Blockchain = Blockchain()

#Ed25519 keys.
edPrivKey: ed25519.SigningKey = ed25519.SigningKey(b'\0' * 32)
edPubKey: ed25519.VerifyingKey = edPrivKey.get_verifying_key()

#BLS keys.
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
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
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
#Mine it.
block.mine(blsPrivKey, blockchain.difficulty())

#Add it.
blockchain.add(block)
print("Generated Invalid Competing Block " + str(len(blockchain.blocks)) + ".")

result: Dict[str, Any] = {
  "blockchain": blockchain.toJSON(),
  "transactions": transactions.toJSON(),
  "removal": mr.toSignedJSON()
}
vectors: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/InvalidCompeting.json", "w")
vectors.write(json.dumps(result))
vectors.close()
