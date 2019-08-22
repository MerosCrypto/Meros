#DB Serialize Consensus Tests.

import Consensus/DBSerializeElementTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(DBSerializeElementTest.test)
