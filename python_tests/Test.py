#Types.
from typing import Callable, List

#TestError Exception.
from python_tests.Tests.TestError import TestError

#Meros classes.
from python_tests.Meros.Meros import Meros
from python_tests.Meros.RPC import RPC

#Tests.
from python_tests.Tests.Merit.ChainAdvancementTest import ChainAdvancementTest
from python_tests.Tests.Merit.SyncTest import MeritSyncTest

from python_tests.Tests.Transactions.DataTest import DataTest
from python_tests.Tests.Transactions.FiftyTest import FiftyTest

from python_tests.Tests.Consensus.MeritRemoval.SameNonce.CauseTest import MRSNCauseTest
from python_tests.Tests.Consensus.MeritRemoval.SameNonce.LiveTest import MRSNLiveTest
from python_tests.Tests.Consensus.MeritRemoval.SameNonce.SyncTest import MRSNSyncTest

from python_tests.Tests.Consensus.MeritRemoval.VerifyCompeting.CauseTest import MRVCCauseTest
from python_tests.Tests.Consensus.MeritRemoval.VerifyCompeting.LiveTest import MRVCLiveTest
from python_tests.Tests.Consensus.MeritRemoval.VerifyCompeting.SyncTest import MRVCSyncTest

from python_tests.Tests.Consensus.MeritRemoval.Partial.CauseTest import MRPCauseTest
from python_tests.Tests.Consensus.MeritRemoval.Partial.LiveTest import MRPLiveTest
from python_tests.Tests.Consensus.MeritRemoval.Partial.SyncTest import MRPSyncTest

from python_tests.Tests.Consensus.MeritRemoval.PendingActions.CauseTest import MRPACauseTest
from python_tests.Tests.Consensus.MeritRemoval.PendingActions.LiveTest import MRPALiveTest

from python_tests.Tests.Consensus.MeritRemoval.MultipleRemovals.CauseTest import MRMRCauseTest
from python_tests.Tests.Consensus.MeritRemoval.MultipleRemovals.LiveTest import MRMRLiveTest

#Arguments.
from sys import argv

#Sleep standard function.
from time import sleep

#SHUtil standard lib.
import shutil

#Format Exception standard function.
from traceback import format_exc

#Initial port.
port: int = 5132

#Results.
ress: List[str] = []

#Tests.
tests: List[
    Callable[[RPC], None]
] = [
    ChainAdvancementTest,
    MeritSyncTest,

    DataTest,
    FiftyTest,

    MRSNCauseTest,
    MRSNLiveTest,
    MRSNSyncTest,

    MRVCCauseTest,
    MRVCLiveTest,
    MRVCSyncTest,

    MRPCauseTest,
    MRPLiveTest,
    MRPSyncTest,

    MRPACauseTest,
    MRPALiveTest,

    MRMRCauseTest,
    MRMRLiveTest
]

#Tests to run.
#If any were specified over the CLI, only run those.
testsToRun: List[str] = argv[1:]
#Else, run all.
if len(testsToRun) == 0:
    for test in tests:
        testsToRun.append(test.__name__)

#Remove invalid tests.
for testName in testsToRun:
    found: bool = False
    for test in tests:
        if test.__name__ == testName:
            found = True
            break

    if not found:
        ress.append("\033[0;31mCouldn't find " + testName + ".")
        testsToRun.remove(testName)

#Delete the python_tests data directory.
try:
    shutil.rmtree("./data/python_tests")
except FileNotFoundError:
    pass

#Run every test.
for test in tests:
    if len(testsToRun) == 0:
        break
    if test.__name__ not in testsToRun:
        continue
    testsToRun.remove(test.__name__)

    print("Running " + test.__name__ + ".")

    meros: Meros = Meros(
        test.__name__,
        port,
        port + 1
    )
    sleep(2)

    rpc: RPC = RPC(meros)
    try:
        test(rpc)
        ress.append("\033[0;32m" + test.__name__ + " succeeded.")
    except TestError as e:
        ress.append("\033[0;31m" + test.__name__ + " failed: " + str(e))
        continue
    except Exception as e:
        print("\033[0;31m" + test.__name__ + " is invalid.")
        raise e
    finally:
        try:
            rpc.quit()
        except Exception:
            ress.append("\033[5;31m" + test.__name__ + " caused the node to crash!\033[0;31m")

        print("-" * shutil.get_terminal_size().columns)

for res in ress:
    print(res)
