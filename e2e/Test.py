#Types.
from typing import Callable, List

#Exceptions.
from e2e.Tests.Errors import EmptyError, NodeError, TestError, SuccessError

#Meros classes.
from e2e.Meros.Meros import Meros
from e2e.Meros.RPC import RPC

#Tests.
from e2e.Tests.Merit.ChainAdvancementTest import ChainAdvancementTest
from e2e.Tests.Merit.DifficultyTest import DifficultyTest
from e2e.Tests.Merit.StateTest import StateTest
from e2e.Tests.Merit.HundredTwentyFourTest import HundredTwentyFourTest
from e2e.Tests.Merit.HundredSeventyFiveTest import HundredSeventyFiveTest
from e2e.Tests.Merit.HundredSeventySevenTest import HundredSeventySevenTest
from e2e.Tests.Merit.Reorganizations.DepthOneTest import DepthOneTest
from e2e.Tests.Merit.Reorganizations.LongerChainMoreWorkTest import LongerChainMoreWorkTest
from e2e.Tests.Merit.Reorganizations.ShorterChainMoreWorkTest import ShorterChainMoreWorkTest
from e2e.Tests.Merit.Reorganizations.DelayedMeritHolderTest import DelayedMeritHolderTest

from e2e.Tests.Merit.Templates.EightyEightTest import EightyEightTest
from e2e.Tests.Merit.Templates.TElementTest import TElementTest

from e2e.Tests.Transactions.DataTest import DataTest
from e2e.Tests.Transactions.AggregatedClaimTest import AggregatedClaimTest
from e2e.Tests.Transactions.SameInputTest import SameInputTest
from e2e.Tests.Transactions.CompetingFinalizedTest import CompetingFinalizedTest
from e2e.Tests.Transactions.FiftyTest import FiftyTest
from e2e.Tests.Transactions.PruneUnaddableTest import PruneUnaddableTest
from e2e.Tests.Transactions.HundredFortySevenTest import HundredFortySevenTest

from e2e.Tests.Consensus.Verification.ParsableTest import VParsableTest
from e2e.Tests.Consensus.Verification.UnknownTest import VUnknownTest
from e2e.Tests.Consensus.Verification.CompetingTest import VCompetingTest
from e2e.Tests.Consensus.Verification.HundredTwoTest import HundredTwoTest
from e2e.Tests.Consensus.Verification.HundredFortyTwoTest import HundredFortyTwoTest
from e2e.Tests.Consensus.Verification.HundredFiftyFiveTest import HundredFiftyFiveTest

from e2e.Tests.Consensus.Difficulties.SendDifficultyTest import SendDifficultyTest
from e2e.Tests.Consensus.Difficulties.DataDifficultyTest import DataDifficultyTest

from e2e.Tests.Consensus.MeritRemoval.SameNonceTest import SameNonceTest
from e2e.Tests.Consensus.MeritRemoval.VerifyCompetingTest import VerifyCompetingTest
from e2e.Tests.Consensus.MeritRemoval.InvalidCompetingTest import InvalidCompetingTest
from e2e.Tests.Consensus.MeritRemoval.PartialTest import PartialTest
from e2e.Tests.Consensus.MeritRemoval.MultipleTest import MultipleTest
from e2e.Tests.Consensus.MeritRemoval.PendingActionsTest import PendingActionsTest
from e2e.Tests.Consensus.MeritRemoval.RepeatTest import RepeatTest
from e2e.Tests.Consensus.MeritRemoval.SameElementTest import SameElementTest
from e2e.Tests.Consensus.MeritRemoval.HundredTwentyTest import HundredTwentyTest

from e2e.Tests.Consensus.MeritRemoval.HundredTwentyThree.HTTPartialTest import HTTPartialTest
from e2e.Tests.Consensus.MeritRemoval.HundredTwentyThree.HTTSwapTest import HTTSwapTest
from e2e.Tests.Consensus.MeritRemoval.HundredTwentyThree.HTTPacketTest import HTTPacketTest

from e2e.Tests.Consensus.MeritRemoval.HundredThirtyThreeTest import HundredThirtyThreeTest
from e2e.Tests.Consensus.MeritRemoval.HundredThirtyFiveTest import HundredThirtyFiveTest

from e2e.Tests.Consensus.HundredSix.HundredSixSignedElementsTest import HundredSixSignedElementsTest
from e2e.Tests.Consensus.HundredSix.HundredSixBlockElementsTest import HundredSixBlockElementsTest
from e2e.Tests.Consensus.HundredSix.HundredSixMeritRemovalsTest import HundredSixMeritRemovalsTest

from e2e.Tests.Network.LANPeersTest import LANPeersTest
from e2e.Tests.Network.ULimitTest import ULimitTest
from e2e.Tests.Network.BusyTest import BusyTest
from e2e.Tests.Network.HundredTwentyFiveTest import HundredTwentyFiveTest

#Arguments.
from sys import argv

#Sleep standard function.
from time import sleep

#ShUtil standard lib.
import shutil

#Format Exception standard function.
from traceback import format_exc

#Initial port.
port: int = 5132

#Results.
ress: List[str] = []

#Tests.
tests: List[Callable[[RPC], None]] = [
  ChainAdvancementTest,
  DifficultyTest,
  StateTest,
  HundredTwentyFourTest,
  HundredSeventyFiveTest,
  HundredSeventySevenTest,
  DepthOneTest,
  LongerChainMoreWorkTest,
  ShorterChainMoreWorkTest,
  DelayedMeritHolderTest,

  EightyEightTest,
  TElementTest,

  DataTest,
  AggregatedClaimTest,
  SameInputTest,
  CompetingFinalizedTest,
  FiftyTest,
  PruneUnaddableTest,
  HundredFortySevenTest,

  VParsableTest,
  VUnknownTest,
  VCompetingTest,
  HundredTwoTest,
  HundredFortyTwoTest,
  HundredFiftyFiveTest,

  SendDifficultyTest,
  DataDifficultyTest,

  SameNonceTest,
  VerifyCompetingTest,
  InvalidCompetingTest,
  PartialTest,
  MultipleTest,
  PendingActionsTest,
  RepeatTest,
  SameElementTest,
  HundredTwentyTest,

  HTTPartialTest,
  HTTSwapTest,
  HTTPacketTest,

  HundredThirtyThreeTest,
  HundredThirtyFiveTest,

  HundredSixSignedElementsTest,
  HundredSixBlockElementsTest,
  HundredSixMeritRemovalsTest,

  LANPeersTest,
  ULimitTest,
  BusyTest,
  HundredTwentyFiveTest
]

#Tests to run.
#If any were specified over the CLI, only run those.
testsToRun: List[str] = argv[1:]
#Else, run all.
if not testsToRun:
  for test in tests:
    testsToRun.append(test.__name__)

#Remove invalid tests.
for t in range(len(testsToRun)):
  found: bool = False
  for test in tests:
    #Enable specifying tests over the CLI without the "Test" suffix.
    if (test.__name__ == testsToRun[t]) or (test.__name__ == testsToRun[t] + "Test"):
      if testsToRun[t][-4:] != "Test":
        testsToRun[t] += "Test"

      found = True
      break

  if not found:
    ress.append("\033[0;31mCouldn't find " + testsToRun[t] + ".")

#Delete the e2e data directory.
try:
  shutil.rmtree("./data/e2e")
except FileNotFoundError:
  pass

#Run every test.
for test in tests:
  if not testsToRun:
    break
  if test.__name__ not in testsToRun:
    continue
  testsToRun.remove(test.__name__)

  print("\033[0;37mRunning " + test.__name__ + ".")

  #Message to display on a Node crash.
  crash: str = "\033[5;31m" + test.__name__ + " caused the node to crash!\033[0;31m"

  #Meros instance.
  meros: Meros = Meros(test.__name__, port, port + 1)
  sleep(5)

  rpc: RPC = RPC(meros)
  try:
    test(rpc)
    raise SuccessError()
  except SuccessError as e:
    ress.append("\033[0;32m" + test.__name__ + " succeeded.")
  except EmptyError as e:
    ress.append("\033[0;33m" + test.__name__ + " is empty.")
  except NodeError as e:
    ress.append(crash)
  except TestError as e:
    ress.append("\033[0;31m" + test.__name__ + " failed: " + str(e))
  except Exception as e:
    ress.append("\033[0;31m" + test.__name__ + " is invalid.")
    ress.append(format_exc().rstrip())
  finally:
    try:
      rpc.quit()
      meros.quit()
    except NodeError:
      if ress[-1] != crash:
        ress.append(crash)

    print("\033[0;37m" + ("-" * shutil.get_terminal_size().columns))

for res in ress:
  print(res)
print("\033[0;37m", end="")
