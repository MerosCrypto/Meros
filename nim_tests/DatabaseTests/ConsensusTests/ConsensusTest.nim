#Consensus Tests.

import ConsensusTests/CDBTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(CDBTest.test)
