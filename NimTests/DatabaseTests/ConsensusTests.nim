#Consensus Tests.

import ConsensusTests/ElementsTest
import ConsensusTests/TransactionStatusTest
import ConsensusTests/SpamFilterTest
import ConsensusTests/ConsensusTest

proc addTests*(
    tests: var seq[proc ()]
) =
    ElementsTest.addTests(tests)
    tests.add(TransactionStatusTest.test)
    tests.add(SpamFilterTest.test)
    ConsensusTest.addTests(tests)
