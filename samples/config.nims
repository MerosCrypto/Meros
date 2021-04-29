#Optimize for size (which is faster than `opt=speed` for Meros (at least on x86_64)).
switch("opt", "size")

#Define release for better performance.
switch("define", "release")

#Enable stackTrace and lineTrace so users can submit workable crash reports.
switch("stackTrace", "on")
switch("lineTrace", "on")

#Enable hints.
switch("hints", "on")

#Enable parallel building.
switch("parallelBuild", "0")

#Specify where to output built objects.
switch("nimcache", thisDir() & "/../build/nimcache/samples")
switch("out", thisDir() & "/../build/Sample")

when defined(merosRelease):
  #Disable extra debug info.
  switch("excessiveStackTrace", "off")
  switch("lineDir", "off")
else:
  #Enable extra debug info.
  switch("debuginfo")
  switch("excessiveStackTrace", "on")
  switch("lineDir", "on")
