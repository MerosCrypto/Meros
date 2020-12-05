#Tests proper handling of an Element from the blockchain which conflicts with an Elemenet in the mempool.
#Meros should archive the Block, then broadcast a partial MeritRemoval with the mempool's DataDifficulty.

from typing import Dict, Any
import json

from e2e.Classes.Consensus.DataDifficulty import DataDifficulty, SignedDataDifficulty
from e2e.Classes.Consensus.MeritRemoval import PartialMeritRemoval

from e2e.Meros.Meros import MessageType
from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError
from e2e.Tests.Consensus.Verify import verifyMeritRemoval

def HundredTwentyTest(
  rpc: RPC
) -> None:
  vectors: Dict[str, Any]
  with open("e2e/Vectors/Consensus/MeritRemoval/HundredTwenty.json", "r") as file:
    vectors = json.loads(file.read())

  #DataDifficulty for the mempool.
  mempoolDataDiff: SignedDataDifficulty = SignedDataDifficulty.fromSignedJSON(vectors["mempoolDataDiff"])
  #DataDifficulty for the Blockchain.
  blockchainDataDiff: DataDifficulty = DataDifficulty.fromJSON(vectors["blockchainDataDiff"])

  def sendDataDifficulty() -> None:
    #Send the Data Difficulty for the mempool.
    rpc.meros.signedElement(mempoolDataDiff)

    #Verify its sent back.
    if rpc.meros.live.recv() != (
      MessageType.SignedDataDifficulty.toByte() +
      mempoolDataDiff.signedSerialize()
    ):
      raise TestError("Meros didn't send us the mempool Data Difficulty.")

  def receiveMeritRemoval() -> None:
    #We should receive a MeritRemoval, which is partial.
    #The unsigned Element should be the Block's DataDifficulty.
    #The signed Element should be the mempool's DataDifficulty.
    if rpc.meros.live.recv() != (
      MessageType.SignedMeritRemoval.toByte() +
      PartialMeritRemoval(blockchainDataDiff, mempoolDataDiff, 0).serialize()
    ):
      raise TestError("Meros didn't create the partial Merit Removal.")

    #Verify Meros didn't just broadcast it, yet also added it.
    verifyMeritRemoval(rpc, 2, 2, 0, True)

  Liver(
    rpc,
    vectors["blockchain"],
    callbacks={
      1: sendDataDifficulty,
      2: receiveMeritRemoval
    }
  ).live()
