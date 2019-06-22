#Hash Tests.

import HashTests/ArgonTest
import HashTests/Blake2Test
import HashTests/SHA3Test
import HashTests/KeccakTest
import HashTests/SHA2Test
import HashTests/RipeMDTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(ArgonTest.test)
    tests.add(Blake2Test.test)
    tests.add(SHA3Test.test)
    tests.add(KeccakTest.test)
    tests.add(SHA2Test.test)
    tests.add(RipeMDTest.test)
