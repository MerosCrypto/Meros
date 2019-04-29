#A fully thread safe, non blocking, logger with three classes of alerts.

#Errors lib.
import Errors

#Async standard lib.
import asyncdispatch

#Locks standard lib.
import locks

#Logger object.
type Logger* = ref object of RootObj
    #Locks to ensure thread safety.
    urgentLock: Lock
    mismatchLock: Lock
    infoLock: Lock
    extraneousLock: Lock

    #Files.
    urgent: File
    mismatch: File
    info: File
    extraneous: File

#Constructor.
proc newLogger*(): Logger {.forceCheck: [].} =
    try:
        result = Logger(
            urgent:     open("data/urgent.log", fmAppend),
            mismatch:   open("data/mismatch.log", fmAppend),
            info:       open("data/info.log", fmAppend),
            extraneous: open("data/etraneous.log", fmAppend)
        )
    except IOError as e:
        doAssert(false, "Couldn't open the log files: " & e.msg)

#Urgent. Displays a message and halts execution.
proc urgent*(
    logger: Logger,
    statement: string
) {.forceCheck: [].} =
    #Print the statement. This will be changed to a dialog box in the future.
    echo statement

    #Acquire the urgent lock.
    acquire(logger.urgentLock)

    #Log it in a file.
    try:
        logger.urgent.writeLine(statement)
    except IOError as e:
        doAssert(false, "Couldn't write to the Logger's urgent log: " & e.msg)

    #Quit.
    quit(-1)

#Mismatch. Logs a message worth looking into but doesn't halt execution.
proc mismatch*(
    logger: Logger,
    statement: string
) {.forceCheck: [], async.} =
    #Acquire the mismatch lock.
    while not tryAcquire(logger.mismatchLock):
        #While we can't acquire it, allow other forceCheck: [], async processes to run.
        try:
            await sleepAsync(1)
        except Exception as e:
            doAssert(false, "Couldn't sleep for 0.001 seconds while waiting to acquire the Logger's mismatch lock: " & e.msg)

    #log it.
    try:
        logger.mismatch.writeLine(statement)
    except IOError as e:
        doAssert(false, "Couldn't write to the Logger's mismatch log: " & e.msg)

    #Unlock the lock.
    release(logger.mismatchLock)

#Info. Logs a generic message.
proc info*(
    logger: Logger,
    statement: string
) {.forceCheck: [], async.} =
    #Acquire the info lock.
    while not tryAcquire(logger.infoLock):
        #While we can't acquire it, allow other forceCheck: [], async processes to run.
        try:
            await sleepAsync(1)
        except Exception as e:
            doAssert(false, "Couldn't sleep for 0.001 seconds while waiting to acquire the Logger's info lock: " & e.msg)

    #log it.
    try:
        logger.info.writeLine(statement)
    except IOError as e:
        doAssert(false, "Couldn't write to the Logger's info log: " & e.msg)

    #Unlock the lock.
    release(logger.infoLock)

#Extranous. Logs a message only worth looking into if you have a rainbow flashes displaying the Star Wars movie.
#Requires debug to be defined.
proc extraneous*(
    logger: Logger,
    statement: string
) {.forceCheck: [], async.} =
    #Only do something when debug is defined.
    when defined(debug):
        #Acquire the extraneous lock.
        while not tryAcquire(logger.extraneousLock):
            #While we can't acquire it, allow other forceCheck: [], async processes to run.
            try:
                await sleepAsync(1)
            except Exception as e:
                doAssert(false, "Couldn't sleep for 0.001 seconds while waiting to acquire the Logger's extraneous lock: " & e.msg)

        #log it.
        try:
            logger.extraneous.writeLine(statement)
        except IOError as e:
            doAssert(false, "Couldn't write to the Logger's extraneous log: " & e.msg)

        #Unlock the lock.
        release(logger.extraneousLock)
