from typing import Dict, List, Any
from time import sleep
import json

from e2e.Libs.Minisketch import Sketch

from e2e.Classes.Transactions.Data import Data
from e2e.Classes.Consensus.Verification import SignedVerification
from e2e.Classes.Consensus.VerificationPacket import VerificationPacket
from e2e.Classes.Merit.Merit import Block, Merit

from e2e.Meros.Meros import MessageType, Meros

from e2e.Tests.Errors import TestError

def MatchesHeaderQuantityTest(
  meros: Meros
) -> None:
  #Create an instance of Merit to make sure the RandomX VM key was set.
  Merit()

  blocks: List[Block]
  txs: List[Data] = []
  verifs: List[SignedVerification] = []
  with open("e2e/Vectors/Merit/TwoHundredSeventyFour/MatchesHeaderQuantity.json", "r") as file:
    vectors: Dict[str, Any] = json.loads(file.read())
    blocks = [Block.fromJSON(block) for block in vectors["blocks"]]
    txs = [Data.fromJSON(tx) for tx in vectors["transactions"]]
    verifs = [SignedVerification.fromSignedJSON(verif) for verif in vectors["verifications"]]

  #Connect.
  meros.liveConnect(blocks[0].header.last)
  meros.syncConnect(blocks[0].header.last)

  #Send a single Block to earn Merit.
  meros.liveBlockHeader(blocks[0].header)
  meros.handleBlockBody(blocks[0])

  #Send the header.
  meros.liveBlockHeader(blocks[1].header)

  #Fail Sketch Resolution, and send a different amount of sketch hashes.
  meros.handleBlockBody(blocks[1], 0)
  if MessageType(meros.sync.recv()[0]) != MessageType.SketchHashesRequest:
    raise TestError("Meros didn't request the hashes after failing sketch resolution.")

  #Send a quantity of sketch hashes that doesn't match the header.
  meros.sketchHashes([Sketch.hash(blocks[1].header.sketchSalt, VerificationPacket(tx.hash, [0])) for tx in txs])
  try:
    if len(meros.sync.recv()) == 0:
      raise TestError()
    raise Exception()
  except TestError:
    pass
  except Exception:
    raise TestError("Meros tried to further sync an invalid Block Body.")

  #Sleep so we can reconnect.
  sleep(65)

  #Repeat setup.
  meros.liveConnect(blocks[0].header.last)
  meros.syncConnect(blocks[0].header.last)

  #Send two Transactions.
  for i in range(2):
    meros.liveTransaction(txs[i])
    meros.signedElement(verifs[i])

  #Send the header and a large enough sketch to cause resolution.
  meros.liveBlockHeader(blocks[1].header)
  meros.handleBlockBody(blocks[1], 3)

  #Should now have been disconnected thanks to having 5 hashes.
  try:
    if len(meros.sync.recv()) == 0:
      raise TestError()
    raise Exception()
  except TestError:
    pass
  except Exception:
    raise TestError("Meros tried to further sync an invalid Block Body.")
