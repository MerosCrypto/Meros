#Serialize/Parse Tests.

import SerializeTests/SerializeTransactionsTests
import SerializeTests/SerializeMeritTests

proc addTests*(
    tests: var seq[proc ()]
) =
    SerializeTransactionsTests.addTests(tests)
    SerializeMeritTests.addTests(tests)
