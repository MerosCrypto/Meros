#Filesystem Tests.

import FilesystemTests/DBTests

proc addTests*(
    tests: var seq[proc ()]
) =
    DBTests.addTests(tests)
