#Serialize/Parse Tests.

import SerializeTests/DBSerializeTransactionsTests
import SerializeTests/DBSerializeMeritTests

proc addTests*(
    tests: var seq[proc ()]
) =
    DBSerializeTransactionsTests.addTests(tests)
    DBSerializeMeritTests.addTests(tests)
