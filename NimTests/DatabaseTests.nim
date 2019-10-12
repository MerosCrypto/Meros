#Database Tests.

import DatabaseTests/FilesystemTests
import DatabaseTests/TransactionsTests
import DatabaseTests/ConsensusTests
import DatabaseTests/MeritTests

proc addTests*(
    tests: var seq[proc ()]
) =
    FilesystemTests.addTests(tests)
    TransactionsTests.addTests(tests)
    ConsensusTests.addTests(tests)
    MeritTests.addTests(tests)
