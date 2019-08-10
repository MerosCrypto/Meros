#Types.
from typing import Callable, List

#TestError Exception.
from python_tests.Tests.TestError import TestError

#Meros classes.
from python_tests.Meros.Meros import Meros
from python_tests.Meros.RPC import RPC

#Tests.
from python_tests.Tests.Merit.ChainAdvancementTest import ChainAdvancementTest
from python_tests.Tests.Merit.SyncTest import SyncTest

from python_tests.Tests.Transactions.DataTest import DataTest
from python_tests.Tests.Transactions.FiftyTest import FiftyTest

from python_tests.Tests.Consensus.MeritRemoval.SameNonceLiveTest import SameNonceLiveTest
from python_tests.Tests.Consensus.MeritRemoval.SameNonceSyncTest import SameNonceSyncTest
from python_tests.Tests.Consensus.MeritRemoval.BlockBeforeArchiveTest import BlockBeforeArchiveTest

#Format Exception standard function.
from traceback import format_exc

#Time standard lib.
import time

#SHUtil standard lib.
import shutil

port: int = 5132
tests: List[
    Callable[[RPC], None]
] = [
    ChainAdvancementTest,
    SyncTest,

    DataTest,
    FiftyTest,

    SameNonceLiveTest,
    SameNonceSyncTest,
    BlockBeforeArchiveTest
]

#Delete the python_tests data directory.
try:
    shutil.rmtree("./data/python_tests")
except FileNotFoundError:
    pass

#Run every test.
ress: List[str] = []
for test in tests:
    name: str = test.__name__
    name.replace(" ", "")

    meros: Meros = Meros(
        name,
        port,
        port + 1
    )
    time.sleep(2)

    rpc: RPC = RPC(meros)
    try:
        test(rpc)
        ress.append("\033[1;32m" + test.__name__ + " succeeded.")
    except TestError as e:
        ress.append("\033[1;31m" + test.__name__ + " failed: " + str(e))
        continue
    except Exception as e:
        print("\033[1;31m" + test.__name__ + " is invalid.")
        raise e
    finally:
        try:
            rpc.quit()
        except Exception:
            ress.append("\033[5;31m" + test.__name__ + " caused the node to crash!")

        print("-" * shutil.get_terminal_size().columns)

for res in ress:
    print(res)
