# pyright: strict

#Types.
from typing import Callable, List

#Meros classes.
from python_tests.Meros.Meros import Meros
from python_tests.Meros.RPC import RPC

#Tests.
from python_tests.Tests.Merit.ChainAdvancementTest import ChainAdvancementTest
from python_tests.Tests.Merit.SyncTest import SyncTest

#Time lib.
import time

port: int = 5132
tests: List[
    Callable[[RPC], None]
] = [
    ChainAdvancementTest,
    SyncTest
]

for test in tests:
    name: str = test.__name__ + str(int(time.time()))
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
