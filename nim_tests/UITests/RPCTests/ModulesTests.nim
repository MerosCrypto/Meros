#Modules Tests.

import ModulesTests/SystemModuleTest
import ModulesTests/TransactionsModuleTest
import ModulesTests/ConsensusModuleTest
import ModulesTests/MeritModuleTest
import ModulesTests/PersonalModuleTest
import ModulesTests/NetworkModuleTest

proc addTests*(
    tests: var seq[proc ()]
) =
    tests.add(SystemModuleTest.test)
    tests.add(TransactionsModuleTest.test)
    tests.add(ConsensusModuleTest.test)
    tests.add(MeritModuleTest.test)
    tests.add(PersonalModuleTest.test)
    tests.add(NetworkModuleTest.test)
