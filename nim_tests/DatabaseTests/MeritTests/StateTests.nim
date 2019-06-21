#State Tests.

import StateTests/SDBTest

import StateTests/ValueTest
import StateTests/RevertTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(SDBTest.test)
    tests.add(ValueTest.test)
    tests.add(RevertTest.test)
