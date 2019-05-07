#Use C++ instead of C.
setCommand("cpp")

#Necessary flags.
switch("threads", "on")
switch("assertions", "on")
switch("define", "ADDRESS_HRP=Mr")
switch("define", "SIGN_PREFIX=MEROS")
switch("define", "DEFAULT_PORT=5132")

when defined(merosRelease):
    #Define release.
    switch("define", "release")

    #Disable checks.
    switch("checks", "off")

    #Re-enaable bound checks.
    switch("boundChecks", "on")

    #Disable extra crash reporting.
    switch("lineDir", "off")
    switch("lineTrace", "off")
    switch("stackTrace", "off")
    switch("excessiveStackTrace", "off")
else:
    #Define release.
    switch("define", "release")

    #Enable finals.
    switch("define", "finalsOn")

    #Enable checks.
    switch("checks", "on")

    #Enable extra crash reporting.
    switch("debuginfo")
    switch("lineDir", "on")
    switch("lineTrace", "on")
    switch("stackTrace", "on")
    switch("excessiveStackTrace", "on")

#Optimize for size (which is faster than `opt=speed` for Meros (at least on x86_64)).
switch("opt", "size")

#Enable parallel building.
switch("parallelBuild", "0")

#Enable hints.
switch("hints", "on")

#Specify where to output built objects.
switch("nimcache", "build/nimcache")
switch("out", "build/Test")
