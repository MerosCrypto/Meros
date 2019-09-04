#DB Serialize Consensus Tests.

import Consensus/DBSerializeElementTest
import Consensus/SerializeTransactionStatusTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(DBSerializeElementTest.test)
    tests.add(SerializeTransactionStatusTest.test)
