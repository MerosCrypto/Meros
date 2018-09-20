#Use C++ instead of C.
if getCommand() == "c":
    setCommand("cpp")

#Necessary flags.
switch("threads", "on")

#Enable assertions and checks.
switch("assertions", "on")
switch("checks", "on")

#Enable extra crash reporting.
switch("debuginfo")
switch("lineDir", "on")
switch("lineTrace", "on")
switch("stackTrace", "on")
switch("excessiveStackTrace", "on")

#Enable parallel building.
switch("parallelBuild", "0")

#Define debug, remove dead code, and optimize for size (which is faster than `opt=speed` for Ember).
switch("define", "debug")
switch("deadCodeElim", "on")
switch("opt", "size")

#Enable hints.
switch("hints", "on")

#Specify where to output built objects.
switch("nimcache", "build/nimcache")
switch("out", "build/Sample")
