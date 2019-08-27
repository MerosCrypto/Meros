#Objects Tests.

import objectsTests/ConfigTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(ConfigTest.test)
