#DB Merit Serialization Tests.

import Merit/SerializeDifficultyTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(SerializeDifficultyTest.test)
