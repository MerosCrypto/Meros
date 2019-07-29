#Interfaces Tests.

import InterfacesTests/RPCTests

proc addTests*(
    tests: var seq[proc ()]
) =
    RPCTests.addTests(tests)
