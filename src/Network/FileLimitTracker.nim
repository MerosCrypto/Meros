#This library returns the max amount of open files, as well as how many files we have open.
#It's under Network/ because its only used to determine if we've hit our max peer count.

#Errors lib.
import ../lib/Errors

#OS standard lib.
import os

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
    raise newException(UnsupportedTarget, "Meros cannot build on this system because it doesn't know how to get the file limit.")

when PROC_FS or DEV_FS:
    proc update*(
        tracker: FileLimitTracker
    ) {.forceCheck: [].} =
        tracker.socketsSinceLastUpdate = 0
        tracker.current = 0
        when PROC_FS:
            for file in walkDir("/proc/self/fd"):
                inc(tracker.current)
        when DEV_FS:
            for file in walkDir("/dev/fd"):
                inc(tracker.current)

else:
    raise newException(UnsupportedTarget, "Meros cannot build on this system because it doesn't know how to get the amount of opened files.")

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
