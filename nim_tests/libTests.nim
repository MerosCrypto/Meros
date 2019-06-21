#Lib Tests.

import libTests/UtilTest
import libTests/Base32Test
import libTests/HashTests
import libTests/LoggerTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(UtilTest.test)
    tests.add(Base32Test.test)
    HashTests.addTests(tests)
    tests.add(LoggerTest.test)
