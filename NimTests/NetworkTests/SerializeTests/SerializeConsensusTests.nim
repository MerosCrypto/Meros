#Consensus Serialization Tests.

import Consensus/SerializeVerificationTest
import Consensus/SerializeVerificationPacketTest
import Consensus/SerializeMeritRemovalTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(SerializeVerificationTest.test)
    tests.add(SerializeVerificationPacketTest.test)
    tests.add(SerializeMeritRemovalTest.test)
