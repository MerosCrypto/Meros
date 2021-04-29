import json

from e2e.Classes.Consensus.SendDifficulty import SignedSendDifficulty
from e2e.Classes.Consensus.DataDifficulty import SignedDataDifficulty

from e2e.Libs.BLS import PrivateKey

from e2e.Meros.RPC import RPC
from e2e.Meros.Liver import Liver

from e2e.Tests.Errors import TestError

#pylint: disable=too-many-statements
def GetDifficultyTest(
  rpc: RPC
) -> None:
  #Check the global difficulty.
  if rpc.call("consensus", "getSendDifficulty", auth=False) != 3:
    raise TestError("getSendDifficulty didn't reply properly.")
  if rpc.call("consensus", "getDataDifficulty", auth=False) != 5:
    raise TestError("getDataDifficulty didn't reply properly.")

  #Check the difficulties for a holder who doesn't exist.
  try:
    rpc.call("consensus", "getSendDifficulty", {"holder": 0}, False)
    raise TestError("")
  except TestError as e:
    if str(e) != "-2 Holder doesn't have a SendDifficulty.":
      raise TestError("getSendDifficulty didn't raise when asked about a non-existent holder.")

  try:
    rpc.call("consensus", "getDataDifficulty", {"holder": 0}, False)
    raise TestError("")
  except TestError as e:
    if str(e) != "-2 Holder doesn't have a DataDifficulty.":
      raise TestError("getDataDifficulty didn't raise when asked about a non-existent holder.")

  def voteAndVerify() ->  None:
    #Check the difficulties for a holder who has yet to vote.
    try:
      rpc.call("consensus", "getSendDifficulty", {"holder": 0}, False)
      raise TestError("")
    except TestError as e:
      if str(e) != "-2 Holder doesn't have a SendDifficulty.":
        raise TestError("getSendDifficulty didn't raise when asked about a holder who has yet to vote.")
    try:
      rpc.call("consensus", "getDataDifficulty", {"holder": 0}, False)
      raise TestError("")
    except TestError as e:
      if str(e) != "-2 Holder doesn't have a DataDifficulty.":
        raise TestError("getDataDifficulty didn't raise when asked about a holder who has yet to vote.")

    #Create the votes.
    sendDiff: SignedSendDifficulty = SignedSendDifficulty(6, 0)
    sendDiff.sign(0, PrivateKey(0))

    dataDiff: SignedDataDifficulty = SignedDataDifficulty(10, 1)
    dataDiff.sign(0, PrivateKey(0))

    #Send them.
    rpc.meros.signedElement(sendDiff)
    rpc.meros.signedElement(dataDiff)
    rpc.meros.live.recv()
    rpc.meros.live.recv()

    #Check them.
    if rpc.call("consensus", "getSendDifficulty", {"holder": 0}, False) != 6:
      raise TestError("getSendDifficulty didn't reply with the holder's current difficulty.")
    if rpc.call("consensus", "getDataDifficulty", {"holder": 0}, False) != 10:
      raise TestError("getDataDifficulty didn't reply with the holder's current difficulty.")

  with open("e2e/Vectors/Merit/BlankBlocks.json", "r") as file:
    Liver(rpc, json.loads(file.read())[:1], callbacks={1: voteAndVerify}).live()
