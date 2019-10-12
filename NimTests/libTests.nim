#Lib Tests.

import libTests/MerkleTest
import libTests/UtilTest
import libTests/HashTests
import libTests/LoggerTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(UtilTest.test)
    HashTests.addTests(tests)
    tests.add(MerkleTest.test)
    tests.add(LoggerTest.test)
