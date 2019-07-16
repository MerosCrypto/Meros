# pyright: strict

#Types.
from typing import List, Callable

#Meros classes.
from python_tests.Meros.Meros import Meros
from python_tests.Meros.RPC import RPC

#Tests.
from python_tests.Merit.ChainAdvancementTest import ChainAdvancementTest

#Time lib.
import time

port: int = 5132
tests: List[Callable[[RPC], None]] = [
    ChainAdvancementTest
]

for test in tests:
    name: str = test.__name__ + str(int(time.time()))
    name.replace(" ", "")

    meros: Meros = Meros(
        name,
        port,
        port + 1
    )
    time.sleep(1)

    rpc: RPC = RPC(meros)
    test(rpc)
    rpc.quit()
