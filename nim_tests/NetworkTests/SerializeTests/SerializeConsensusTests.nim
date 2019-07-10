#Consensus Serialization Tests.

import Consensus/SerializeVerificationTest
import Consensus/SerializeMeritRemovalTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(SerializeVerificationTest.test)
    tests.add(SerializeMeritRemovalTest.test)
