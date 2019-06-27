#DB Serialize Consensus Tests.

import Consensus/SerializeUnknownTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(SerializeUnknownTest.test)
