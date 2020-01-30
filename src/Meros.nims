#Necessary flags.
switch("threads", "on")
switch("experimental", "caseStmtMacros")
switch("define", "SIGN_PREFIX=MEROS")
switch("define", "ADDRESS_HRP=mr")
switch("define", "COIN_TYPE=5132")
switch("define", "DEFAULT_PORT=5132")

#Optimize for size (which is faster than `opt=speed` for Meros (at least on x86_64)).
switch("opt", "size")

#Define release for usable StInt performance.
switch("define", "release")

#Enable stackTrace and lineTrace so users can submit workable crash reports.
switch("stackTrace", "on")
switch("lineTrace", "on")

#Enable hints.
switch("hints", "on")

#Enable parallel building.
switch("parallelBuild", "0")

#Specify where to output built objects.
switch("nimcache", thisDir() & "/../build/nimcache/Meros")
switch("out", thisDir() & "/../build/Meros")

#Chronicles settings.
switch("define", "chronicles_sinks:textlines[file]")
switch("define", "chronicles_log_level:TRACE")

when defined(merosRelease):
    #Disable extra debug info.
    switch("excessiveStackTrace", "off")
    switch("lineDir", "off")
else:
    #Enable extra debug info.
    switch("debuginfo")
    switch("excessiveStackTrace", "on")
    switch("lineDir", "on")
