#This library returns the max amount of open files, as well as how many files we have open.
#It's under Network/ because its only used to determine if we've hit our max peer count.

when not defined(MacOSX):
  import os
else:
  import osproc
  import strutils

import ../lib/Errors

const
  #Amount of files to reserve. Any Peer that fits into this buffer will be sent Busy and disconnected.
  BUFFER_FILES {.intdefine.} = 16
  #Whether or not getrlimit is available.
  GETRLIMIT: bool = defined(Linux) or defined(NetBSD) or defined(FreeBSD) or defined(OpenBSD) or defined(MacOS) or defined(MacOSX)
  #Whether or not /proc exists and can be used to get the amount of open file handles.
  PROC_FS: bool = defined(Linux)
  #Whether or not to use /dev/fd to get the amount of open file handles.
  DEV_FS: bool = defined(NetBSD) or defined(FreeBSD) or defined(OpenBSD) or defined(MacOS) or defined(MacOSX)

type
  FileLimitTracker* = ref object
    max: int
    current: int
    socketsSinceLastUpdate: int

  PeerStatus* = enum
    Valid = 0,
    Busy = 1

when GETRLIMIT:
  type RLimit = object
    rlim_curr: cuint
    rlim_max: cuint

  var RLIMIT_NOFILE {.importc: "RLIMIT_NOFILE", noDecl.}: cint

  proc cGetRLimit(
    resource: cint,
    result: ptr RLimit
  ): cint {.header: "sys/resource.h", importc: "getrlimit".}

  proc getMaxFiles(): int {.forceCheck: [].} =
    var limit: RLimit
    if cGetRLimit(RLIMIT_NOFILE, addr limit) != 0:
      panic("Couldn't get the system's file limit.")
    result = int(limit.rlim_curr)
elif defined(WINDOWS):
  proc getMaxFiles(): int {.inline, forceCheck: [].} =
    512
else:
  {.fatal: "Meros cannot build on this system because it doesn't know how to get the file limit.".}

when PROC_FS or DEV_FS:
  proc update*(
    tracker: FileLimitTracker
  ) {.forceCheck: [].} =
    try:
      when PROC_FS:
        tracker.current = 0
        for file in walkDir("/proc/self/fd"):
          inc(tracker.current)
      elif DEV_FS:
        #This is horrific. We SHOULD call walkDir again.
        #That said, walkDir doesn't work; it kept returning 0 .. 9 and 10 if it exists.
        #This still works and should work on every Mac due to its extremely basic command usage.
        #If a proper solution exists, please let me know.
        #-- Kayaba
        try:
          tracker.current = parseInt(execProcess("ls /dev/fd | wc -l").strip())
        except ValueError as e:
          panic("wc -l didn't return an integer: " & e.msg)
        except Exception as e:
          panic("Couldn't run wc and ls: " & e.msg)
    except OSError as e:
      panic("Couldn't detect the amount of open files: " & e.msg)
    tracker.socketsSinceLastUpdate = 0

else:
  {.fatal: "Meros cannot build on this system because it doesn't know how to get the amount of opened files.".}

proc newFileLimitTracker*(): FileLimitTracker {.forceCheck: [].} =
  result = FileLimitTracker(
    current: 0,
    max: getMaxFiles()
  )
  result.update()

proc allocateSocket*(
  tracker: FileLimitTracker
): PeerStatus {.forceCheck: [].} =
  if (tracker.current + tracker.socketsSinceLastUpdate) < (tracker.max - BUFFER_FILES):
    inc(tracker.socketsSinceLastUpdate)
    result = PeerStatus.Valid
  else:
    result = PeerStatus.Busy
