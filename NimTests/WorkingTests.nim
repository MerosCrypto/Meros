#Run every working Test.

import SyntaxTest

import objectsTests
import libTests
import WalletTests
#import DatabaseTests
import NetworkTests

import DatabaseTests/FilesystemTests
import DatabaseTests/MeritTests/BlockchainTests
import DatabaseTests/MeritTests/StateTests

import DatabaseTests/MeritTests/EpochsTests/EmptyTest
#[
import DatabaseTests/MeritTests/EpochsTests/SingleTest
import DatabaseTests/MeritTests/EpochsTests/SplitTest
import DatabaseTests/MeritTests/EpochsTests/Perfect1000Test
]#

#Locks standard lib.
import locks

#Thread standard lib.
import threadpool

var
    tests: seq[proc ()] = @[]
    testID: int = 0
    testLock: Lock
initLock(testLock)

objectsTests.addTests(tests)
libTests.addTests(tests)
WalletTests.addTests(tests)
#DatabaseTests.addTests(tests)
NetworkTests.addTests(tests)

FilesystemTests.addTests(tests)
BlockchainTests.addTests(tests)
StateTests.addTests(tests)

tests.add(EmptyTest.test)
#[
tests.add(SingleTest.test)
tests.add(SplitTest.test)
tests.add(Perfect1000Test.test)
]#

proc grabTest(): int =
    {.gcsafe.}:
        acquire(testLock)
        result = testID
        inc(testID)
        release(testLock)

proc test*() {.thread.} =
    {.gcsafe.}:
        while true:
            var id: int = grabTest()
            if id >= tests.len:
                break

            tests[id]()

for _ in 0 ..< 8:
    spawn test()

sync()

echo "Finished all the Tests."
