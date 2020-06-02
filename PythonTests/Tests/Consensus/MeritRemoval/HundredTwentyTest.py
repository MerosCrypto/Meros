#Tests proper handling of an Element from the blockchain which conflicts with an Elemenet in the mempool.
#Meros should archive the Block, then broadcast a partial MeritRemoval with the mempool's DataDifficulty.

#Types.
from typing import Dict, IO, Any

#DataDifficulty classes.
from PythonTests.Classes.Consensus.DataDifficulty import DataDifficulty, SignedDataDifficulty
#Parital MeritRemoval class.
from PythonTests.Classes.Consensus.MeritRemoval import PartialMeritRemoval

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.Meros import MessageType
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver

#MeritRemoval verifier.
from PythonTests.Tests.Consensus.Verify import verifyMeritRemoval

#JSON standard lib.
import json

def HundredTwentyTest(
  rpc: RPC
) -> None:
  file: IO[Any] = open("PythonTests/Vectors/Consensus/MeritRemoval/HundredTwenty.json", "r")
  vectors: Dict[str, Any] = json.loads(file.read())
  file.close()

  #DataDifficulty for the mempool.
  #pylint: disable=no-member
  mempoolDataDiff: SignedDataDifficulty = SignedDataDifficulty.fromSignedJSON(vectors["mempoolDataDiff"])
  #DataDifficulty for the Blockchain.
  #pylint: disable=no-member
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
      PartialMeritRemoval(
        blockchainDataDiff,
        mempoolDataDiff,
        0
      ).signedSerialize()
    ):
      raise TestError("Meros didn't create the partial Merit Removal.")

    #Verify Meros didn't just broadcast it, yet also added it.
    verifyMeritRemoval(rpc, 1, 1, 0, False)

  Liver(
    rpc,
    vectors["blockchain"],
    callbacks={
      1: sendDataDifficulty,
      2: receiveMeritRemoval
    }
  ).live()
