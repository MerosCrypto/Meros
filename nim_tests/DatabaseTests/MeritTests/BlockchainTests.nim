#Blockchain Tests.

import BlockchainTests/BDBTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(BDBTest.test)
