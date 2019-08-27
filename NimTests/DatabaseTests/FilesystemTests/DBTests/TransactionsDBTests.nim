#TransactionsDB Tests.

import TransactionsDBTests/SpendableTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(SpendableTest.test)
