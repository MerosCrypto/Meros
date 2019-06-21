#Run every Test...

import SyntaxTest

import objectsTests
import libTests
import WalletTests
import DatabaseTests
import UITests
import NetworkTests

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
DatabaseTests.addTests(tests)

proc grabTest(): int =
    {.gcsafe.}:
        acquire(testLock)
        result = testID
        inc(testID)
        release(testLock)

proc test*(i: int) {.thread.} =
    {.gcsafe.}:
        while true:
            var id: int = grabTest()
            if id >= tests.len:
                break

            tests[id]()

for i in 0 ..< 8:
    spawn test(i)

sync()

echo "Finished all the Tests."
