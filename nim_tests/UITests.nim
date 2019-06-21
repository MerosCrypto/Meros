#UI Tests.

import UITests/RPCTests

proc addTests*(
    tests: var seq[proc ()]
) =
    RPCTests.addTests(tests)
