#DB Serialize/Parse Tests.

import SerializeTests/DBSerializeTransactionsTests
import SerializeTests/DBSerializeConsensusTests
import SerializeTests/DBSerializeMeritTests

proc addTests*(
    tests: var seq[proc ()]
) =
    DBSerializeTransactionsTests.addTests(tests)
    DBSerializeConsensusTests.addTests(tests)
    DBSerializeMeritTests.addTests(tests)
