#Lib Tests.

import libTests/UtilTest
import libTests/HashTests
import libTests/LoggerTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(UtilTest.test)
    HashTests.addTests(tests)
    tests.add(LoggerTest.test)
