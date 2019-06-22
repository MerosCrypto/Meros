#Consensus Serialization Tests.

import Consensus/SerializeVerificationTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(SerializeVerificationTest.test)
