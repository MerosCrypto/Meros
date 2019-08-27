#Transactions Tests.

import TransactionsTests/MintTest
import TransactionsTests/ClaimTest
import TransactionsTests/SendTest
import TransactionsTests/TransactionsTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(MintTest.test)
    tests.add(ClaimTest.test)
    tests.add(SendTest.test)
    TransactionsTest.addTests(tests)
