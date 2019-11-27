#Merit Serialization Tests.

import Merit/SerializeBlockHeaderTest
import Merit/SerializeBlockBodyTest
import Merit/SerializeBlockTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(SerializeBlockHeaderTest.test)
    tests.add(SerializeBlockBodyTest.test)
    tests.add(SerializeBlockTest.test)
