#Network Tests.

import NetworkTests/SerializeTests

proc addTests*(
    tests: var seq[proc ()]
) =
    SerializeTests.addTests(tests)
