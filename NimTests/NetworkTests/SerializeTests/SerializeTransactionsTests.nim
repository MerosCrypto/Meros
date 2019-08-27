#Serialize Transactions Tests.

import Transactions/SerializeClaimTest
import Transactions/SerializeSendTest
import Transactions/SerializeDataTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(SerializeClaimTest.test)
    tests.add(SerializeSendTest.test)
    tests.add(SerializeDataTest.test)
