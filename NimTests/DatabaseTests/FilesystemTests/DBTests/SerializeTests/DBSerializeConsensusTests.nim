#DB Serialize Consensus Tests.

import Consensus/SerializeTransactionStatusTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(SerializeTransactionStatusTest.test)
