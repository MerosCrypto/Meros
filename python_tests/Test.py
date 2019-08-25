#Types.
from typing import Callable, List

#Exceptions.
from python_tests.Tests.Errors import EmptyError, NodeError, TestError

#Meros classes.
from python_tests.Meros.Meros import Meros
from python_tests.Meros.RPC import RPC

#Tests.
from python_tests.Tests.Merit.ChainAdvancementTest import ChainAdvancementTest
from python_tests.Tests.Merit.SyncTest import MSyncTest

from python_tests.Tests.Transactions.DataTest import DataTest
from python_tests.Tests.Transactions.FiftyTest import FiftyTest

from python_tests.Tests.Consensus.Verification.UnknownTest import VUnknownTest
from python_tests.Tests.Consensus.Verification.ParsableTest import VParsableTest
from python_tests.Tests.Consensus.Verification.CompetingTest import VCompetingTest

from python_tests.Tests.Consensus.MeritRemoval.SameNonce.CauseTest import MRSNCauseTest
from python_tests.Tests.Consensus.MeritRemoval.SameNonce.LiveTest import MRSNLiveTest
from python_tests.Tests.Consensus.MeritRemoval.SameNonce.SyncTest import MRSNSyncTest

from python_tests.Tests.Consensus.MeritRemoval.VerifyCompeting.CauseTest import MRVCCauseTest
from python_tests.Tests.Consensus.MeritRemoval.VerifyCompeting.LiveTest import MRVCLiveTest
from python_tests.Tests.Consensus.MeritRemoval.VerifyCompeting.SyncTest import MRVCSyncTest

from python_tests.Tests.Consensus.MeritRemoval.Multiple.CauseTest import MRMCauseTest
from python_tests.Tests.Consensus.MeritRemoval.Multiple.LiveTest import MRMLiveTest

from python_tests.Tests.Consensus.MeritRemoval.Partial.CauseTest import MRPCauseTest
from python_tests.Tests.Consensus.MeritRemoval.Partial.LiveTest import MRPLiveTest
from python_tests.Tests.Consensus.MeritRemoval.Partial.SyncTest import MRPSyncTest

from python_tests.Tests.Consensus.MeritRemoval.PendingActions.CauseTest import MRPACauseTest
from python_tests.Tests.Consensus.MeritRemoval.PendingActions.LiveTest import MRPALiveTest

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
    MSyncTest,

    DataTest,
    FiftyTest,

    VUnknownTest,
    VParsableTest,
    VCompetingTest,

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

    MRMCauseTest,
    MRMLiveTest
]

#Tests to run.
#If any were specified over the CLI, only run those.
testsToRun: List[str] = argv[1:]
#Else, run all.
if not testsToRun:
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
    if not testsToRun:
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
    except EmptyError as e:
        ress.append("\033[0;33m" + test.__name__ + " is empty.")
        continue
    except NodeError as e:
        ress.append("\033[5;31m" + test.__name__ + " caused the node to crash!\033[0;31m")
    except TestError as e:
        ress.append("\033[0;31m" + test.__name__ + " failed: " + str(e))
        continue
    except Exception as e:
        ress.append("\r\n")
        ress.append("\033[0;31m" + test.__name__ + " is invalid.")
        ress.append(format_exc())
    finally:
        try:
            rpc.quit()
        except NodeError:
            ress.append("\033[5;31m" + test.__name__ + " caused the node to crash!\033[0;31m")

        print("-" * shutil.get_terminal_size().columns)

for res in ress:
    print(res)
