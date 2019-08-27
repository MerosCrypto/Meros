#Database Tests.

import DatabaseTests/commonTests
import DatabaseTests/FilesystemTests
import DatabaseTests/TransactionsTests
import DatabaseTests/ConsensusTests
import DatabaseTests/MeritTests

proc addTests*(
    tests: var seq[proc ()]
) =
    commonTests.addTests(tests)
    FilesystemTests.addTests(tests)
    TransactionsTests.addTests(tests)
    ConsensusTests.addTests(tests)
    MeritTests.addTests(tests)
