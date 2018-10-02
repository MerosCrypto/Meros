#Use C++ instead of C.
if getCommand() == "c":
    setCommand("cpp")

#Necessary flags.
switch("threads", "on")
switch("assertions", "on")

when defined(release):
    #Disable checks.
    switch("checks", "on")

    #Disable extra crash reporting.
    switch("lineDir", "off")
    switch("lineTrace", "off")
    switch("stackTrace", "off")
    switch("excessiveStackTrace", "off")
else:
    #Define debug.
    switch("define", "debug")

    #Enable checks.
    switch("checks", "on")

    #Enable extra crash reporting.
    switch("debuginfo")
    switch("lineDir", "on")
    switch("lineTrace", "on")
    switch("stackTrace", "on")
    switch("excessiveStackTrace", "on")

#Remove dead code and optimize for size (which is faster than `opt=speed` for Ember).
switch("deadCodeElim", "on")
switch("opt", "size")

#Enable parallel building.
switch("parallelBuild", "0")

#Enable hints.
switch("hints", "on")

#Specify where to output built objects.
switch("nimcache", "build/nimcache")
switch("out", "build/Test")
