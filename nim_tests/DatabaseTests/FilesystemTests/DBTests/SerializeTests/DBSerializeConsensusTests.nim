#DB Serialize Consensus Tests.

import Consensus/DBSerializeElementTest
import Consensus/SerializeUnknownTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(DBSerializeElementTest.test)
    tests.add(SerializeUnknownTest.test)
