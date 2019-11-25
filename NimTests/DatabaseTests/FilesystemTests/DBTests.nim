#DB Tests.

import DBTests/DBSerializeTests
import DBTests/TransactionsDBTests
import DBTests/ConsensusDBTest
import DBTests/MeritDBTest

proc addTests*(
    tests: var seq[proc ()]
) =
    DBSerializeTests.addTests(tests)
    TransactionsDBTests.addTests(tests)
    tests.add(ConsensusDBTest.test)
    tests.add(MeritDBTest.test)
