from typing import Dict, Any
import json

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.Meros import Meros

from e2e.Tests.Errors import TestError

#This test is based on a crash from an old algorithm that was removed.
#Therefore, this test doesn't really do anything.
#It was used to verify the old algo was the problem, yet that's gone now.
#Now this just verifies the crash won't pop back up, except it was so specifically coded...
#Beyond that, it doesn't verify the data it creates would trigger the old algorithm.
#Any change to Data transactions would cause this test to no longer do what it's supposed to.
#TL;DR This test is fragile and pretty pointless.
#It does test the case where the differences are used on local packets not in the Block though.
def TwoHundredSixtyThreeTest(
  meros: Meros
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Merit/Sketches/TwoHundredSixtyThree.json", "r") as file:
    vectors = json.loads(file.read())

  blockchain: Blockchain = Blockchain.fromJSON(vectors["blockchain"])

  meros.liveConnect(blockchain.blocks[0].header.hash)
  meros.syncConnect(blockchain.blocks[0].header.hash)

  header: bytes = meros.liveBlockHeader(blockchain.blocks[1].header)
  meros.handleBlockBody(blockchain.blocks[1])
  if meros.live.recv() != header:
    raise TestError("Meros didn't broadcast a BlockHeader for a Block it just added.")

  for data in vectors["datas"]:
    if meros.liveTransaction(Data.fromJSON(data)) != meros.live.recv():
      raise TestError("Meros didn't broadcast back a Data Transaction.")

  for verif in vectors["verifications"]:
    if meros.signedElement(SignedVerification.fromSignedJSON(verif)) != meros.live.recv():
      raise TestError("Meros didn't broadcast back a Verification.")

  header = meros.liveBlockHeader(blockchain.blocks[2].header)
  meros.handleBlockBody(blockchain.blocks[2], (len(blockchain.blocks[2].body.packets) // 5) + 1)
  if meros.live.recv() != header:
    raise TestError("Meros didn't broadcast a BlockHeader for a Block it just added.")
