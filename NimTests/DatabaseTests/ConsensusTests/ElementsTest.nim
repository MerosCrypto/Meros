#Elements Tests.

import ElementsTests/ElementTest
import ElementsTests/VerificationTest
import ElementsTests/VerificationPacketTest
import ElementsTests/SendDifficultyTest
import ElementsTests/DataDifficultyTest
import ElementsTests/GasPriceTest
import ElementsTests/MeritRemovalTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(ElementTest.test)
    tests.add(VerificationTest.test)
    tests.add(VerificationPacketTest.test)
    tests.add(SendDifficultyTest.test)
    tests.add(DataDifficultyTest.test)
    tests.add(GasPriceTest.test)
    tests.add(MeritRemovalTest.test)
