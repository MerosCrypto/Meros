#Transactions Tests.

import TransactionsTests/TDBTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(TDBTest.test)
