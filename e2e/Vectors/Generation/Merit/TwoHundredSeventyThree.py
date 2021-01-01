import json

from e2e.Libs.BLS import PrivateKey
from e2e.Libs.RandomX import RandomX

from e2e.Classes.Merit.Blockchain import BlockHeader, Blockchain

privKey: PrivateKey = PrivateKey(0)

blockchain: Blockchain = Blockchain()
header: BlockHeader = BlockHeader(
  0,
  blockchain.last(),
  bytes(32),
  0,
  bytes(4),
  bytes(32),
  privKey.toPublicKey().serialize(),
  1200
)

difficulty: int = blockchain.difficulties[-1]
raisedDifficulty: int = difficulty * 11 // 10

header.proof = -1
while (
  (header.proof == -1) or
  #Standard difficulty check. Can't overflow against the difficulty.
  ((int.from_bytes(header.hash, "little") * difficulty) > int.from_bytes(bytes.fromhex("FF" * 32), "little")) or
  #That said, it also can't beat the raised difficulty it should.
  ((int.from_bytes(header.hash, "little") * raisedDifficulty) <= int.from_bytes(bytes.fromhex("FF" * 32), "little"))
):
  header.proof += 1
  header.hash = RandomX(header.serializeHash())
  header.signature = privKey.sign(header.hash).serialize()
  header.hash = RandomX(header.hash + header.signature)

with open("e2e/Vectors/Merit/TwoHundredSeventyThree.json", "w") as vectors:
  vectors.write(json.dumps(header.toJSON()))
