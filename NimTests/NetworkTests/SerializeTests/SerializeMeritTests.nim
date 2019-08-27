#Merit Serialization Tests.

import Merit/SerializeRecordsTest
import Merit/SerializeMinersTest
import Merit/SerializeBlockHeaderTest
import Merit/SerializeBlockBodyTest
import Merit/SerializeBlockTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(SerializeRecordsTest.test)
    tests.add(SerializeMinersTest.test)
    tests.add(SerializeBlockHeaderTest.test)
    tests.add(SerializeBlockBodyTest.test)
    tests.add(SerializeBlockTest.test)
