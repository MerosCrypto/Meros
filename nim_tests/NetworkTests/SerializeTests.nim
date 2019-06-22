#Serialize/Parse Tests.

import SerializeTests/SerializeTransactionsTests
import SerializeTests/SerializeConsensusTests
import SerializeTests/SerializeMeritTests

proc addTests*(
    tests: var seq[proc ()]
) =
    SerializeTransactionsTests.addTests(tests)
    SerializeConsensusTests.addTests(tests)
    SerializeMeritTests.addTests(tests)
