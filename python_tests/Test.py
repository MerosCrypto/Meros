#Types.
from typing import Callable, List

#Meros classes.
from python_tests.Meros.Meros import Meros
from python_tests.Meros.RPC import RPC

#Tests.
from python_tests.Tests.Merit.ChainAdvancementTest import ChainAdvancementTest
from python_tests.Tests.Merit.SyncTest import SyncTest

from python_tests.Tests.Transactions.DataTest import DataTest
from python_tests.Tests.Transactions.FiftyTest import FiftyTest

from python_tests.Tests.Consensus.MeritRemoval.SameNonceTest import SameNonceTest

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
    SameNonceTest
]

#Delete the python_tests data directory.
try:
    shutil.rmtree("./data/python_tests")
except FileNotFoundError:
    pass

#Run every test.
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
    except Exception as e:
        rpc.quit()
        raise e
    rpc.quit()

    print("--")
