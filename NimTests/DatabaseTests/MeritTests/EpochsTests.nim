#Epochs Tests.

import EpochsTests/EDBTest

import EpochsTests/EmptyTest
import EpochsTests/SingleTest
import EpochsTests/SplitTest
import EpochsTests/TieBreakTest
import EpochsTests/Perfect1000Test

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(EDBTest.test)
    tests.add(EmptyTest.test)
    tests.add(SingleTest.test)
    tests.add(SplitTest.test)
    tests.add(TieBreakTest.test)
    tests.add(Perfect1000Test.test)
