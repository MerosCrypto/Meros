#common Tests.

import commonTests/MerkleTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(MerkleTest.test)
