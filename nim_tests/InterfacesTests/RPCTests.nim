#RPC Tests.

import RPCTests/RPCTest
import RPCTests/ModulesTests

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(RPCTest.test)
    ModulesTests.addTests(tests)
