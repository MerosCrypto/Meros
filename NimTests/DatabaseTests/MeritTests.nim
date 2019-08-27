#Merit Tests.

import MeritTests/BlockHeaderTest
import MeritTests/BlockTest
import MeritTests/DifficultyTest
import MeritTests/BlockchainTests
import MeritTests/StateTests
import MeritTests/EpochsTests
import MeritTests/MeritTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(BlockHeaderTest.test)
    tests.add(BlockTest.test)
    tests.add(DifficultyTest.test)
    BlockchainTests.addTests(tests)
    StateTests.addTests(tests)
    EpochsTests.addTests(tests)
    tests.add(MeritTest.test)
