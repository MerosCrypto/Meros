#Define "merosTests".
switch("define", "merosTests")

#Necessary flags.
switch("threads", "on")
switch("experimental", "caseStmtMacros")
switch("define", "SIGN_PREFIX=MEROS")
switch("define", "ADDRESS_HRP=bc")
switch("define", "COIN_TYPE=5132")
switch("define", "DEFAULT_PORT=5132")
switch("define", "MESSAGE_LENGTH_LIMIT=8388608")
switch("define", "BUFFER_FILES=16")

#Optimize for size (which is faster than `opt=speed` for Meros (at least on x86_64)).
switch("opt", "size")

#Define release for usable StInt performance.
switch("define", "release")

#Enable stackTrace and lineTrace so users can submit workable crash reports.
switch("stackTrace", "on")
switch("lineTrace", "on")

#Enable hints.
switch("hints", "off")

#Enable parallel building.
switch("parallelBuild", "0")

#Specify where to output built objects.
switch("nimcache", thisDir() & "/../build/nimcache/tests")
switch("outdir", thisDir() & "/../build/tests")

when defined(merosRelease):
  #Disable extra debug info.
  switch("excessiveStackTrace", "off")
  switch("lineDir", "off")
else:
  #Enable extra debug info.
  switch("debuginfo")
  switch("excessiveStackTrace", "on")
  switch("lineDir", "on")
