#Consensus Serialization Tests.

import Consensus/ParseElementTest
import Consensus/SerializeVerificationTest
import Consensus/SerializeVerificationPacketTest
import Consensus/SerializeDataDifficultyTest
import Consensus/SerializeMeritRemovalTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(ParseElementTest.test)
    tests.add(SerializeVerificationTest.test)
    tests.add(SerializeVerificationPacketTest.test)
    tests.add(SerializeDataDifficultyTest.test)
    tests.add(SerializeMeritRemovalTest.test)
