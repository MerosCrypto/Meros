#DB Tests.

import DBTests/DBTest
import DBTests/SerializeTests
import DBTests/TransactionsDBTests
import DBTests/ConsensusDBTest
import DBTests/MeritDBTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(DBTest.test)
    SerializeTests.addTests(tests)
    TransactionsDBTests.addTests(tests)
    tests.add(ConsensusDBTest.test)
    tests.add(MeritDBTest.test)
