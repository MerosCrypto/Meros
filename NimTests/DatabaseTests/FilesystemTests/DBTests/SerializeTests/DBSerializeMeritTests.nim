#DB Merit Serialization Tests.

import Merit/SerializeDifficultyTest
import Merit/DBSerializeBlockTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(SerializeDifficultyTest.test)
    tests.add(DBSerializeBlockTest.test)
