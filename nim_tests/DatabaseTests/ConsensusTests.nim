#Consensus Tests.

import ConsensusTests/ElementTest
import ConsensusTests/SendDifficultyTest
import ConsensusTests/DataDifficultyTest
import ConsensusTests/GasPriceTest
import ConsensusTests/MeritRemovalTest
import ConsensusTests/MeritHolderTest
import ConsensusTests/ConsensusTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(ElementTest.test)
    tests.add(SendDifficultyTest.test)
    tests.add(DataDifficultyTest.test)
    tests.add(GasPriceTest.test)
    tests.add(MeritRemovalTest.test)
    tests.add(MeritHolderTest.test)
    ConsensusTest.addTests(tests)
