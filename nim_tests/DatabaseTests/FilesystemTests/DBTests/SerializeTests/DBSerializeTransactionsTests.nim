#DB Serialize Transactions Tests.

import Transactions/SerializeMintOutputTest
import Transactions/SerializeSendOutputTest

import Transactions/SerializeMintTest
import Transactions/SerializeTransactionTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(SerializeMintOutputTest.test)
    tests.add(SerializeSendOutputTest.test)
    tests.add(SerializeMintTest.test)
    tests.add(SerializeTransactionTest.test)
