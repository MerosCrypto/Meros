#Use C++ instead of C.
setCommand("cpp")

#Necessary flags.
switch("threads", "on")
switch("experimental", "caseStmtMacros")
switch("define", "SIGN_PREFIX=MEROS")
switch("define", "ADDRESS_HRP=Mr")
switch("define", "COIN_TYPE=5132")
switch("define", "DEFAULT_PORT=5132")

#Optimize for size (which is faster than `opt=speed` for Meros (at least on x86_64)).
switch("opt", "size")

#Define release for usable StInt performance.
switch("define", "release")

#Enable stackTrace and lineTrace so users can submit workable crash reports.
switch("stackTrace", "on")
switch("lineTrace", "on")

#Disable checks.
#We previously had checks enabled. This creates inconsistent release/debug conditions.
switch("checks", "off")

#Re-enable assertions.
switch("assertions", "on")

#Enable hints.
switch("hints", "on")

#Enable parallel building.
switch("parallelBuild", "0")

#Specify where to output built objects.
switch("nimcache", thisDir() & "/../build/nimcache/tests")
switch("out", thisDir() & "/../build/Test")

when defined(merosRelease):
    #Disable finals.
    switch("define", "finalsOff")

    #Disable extra debug info.
    switch("excessiveStackTrace", "off")
    switch("lineDir", "off")
else:
    #Enable finals.
    switch("define", "finalsOn")

    #Enable extra debug info.
    switch("debuginfo")
    switch("excessiveStackTrace", "on")
    switch("lineDir", "on")
