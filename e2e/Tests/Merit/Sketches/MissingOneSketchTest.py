from typing import Dict, Any
import json

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Merit.Blockchain import Blockchain

from e2e.Meros.Meros import MessageType, Meros

from e2e.Tests.Errors import TestError

def MissingOneSketchTest(
  meros: Meros
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Merit/Sketches/MissingOne.json", "r") as file:
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
  meros.handleBlockBody(blockchain.blocks[2], 1)

  if MessageType(meros.sync.recv()[0]) != MessageType.SketchHashRequests:
    raise TestError("Meros didn't request the packet it's missing.")
  meros.packet(VerificationPacket.fromJSON(vectors["packet"]))

  if meros.live.recv() != header:
    raise TestError("Meros didn't broadcast a BlockHeader for a Block it just added.")
