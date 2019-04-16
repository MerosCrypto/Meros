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
    except IOError:
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
    except IOError:
        discard

    #Quit.
    quit(-1)

#Mismatch. Logs a message worth looking into but doesn't halt execution.
func mismatch*(
    logger: Logger,
    statement: string
) {.forceCheck: [], async.} =
    #Acquire the mismatch lock.
    while not tryAcquire(logger.mismatchLock):
        #While we can't acquire it, allow other forceCheck: [], async processes to run.
        await sleepAsync(1)

    #log it.
    logger.mismatch.writeLine(statement)

    #Unlock the lock.
    release(logger.mismatchLock)

#Info. Logs a generic message.
func info*(
    logger: Logger,
    statement: string
) {.forceCheck: [], async.} =
    #Acquire the info lock.
    while not tryAcquire(logger.infoLock):
        #While we can't acquire it, allow other forceCheck: [], async processes to run.
        await sleepAsync(1)

    #log it.
    logger.info.writeLine(statement)

    #Unlock the lock.
    release(logger.infoLock)

#Extranous. Logs a message only worth looking into if you have a rainbow flashes displaying the Star Wars movie.
#Requires debug to be defined.
func extraneous*(
    logger: Logger,
    statement: string
) {.forceCheck: [], async.} =
    #Only do something when debug is defined.
    when defined(debug):
        #Acquire the extraneous lock.
        while not tryAcquire(logger.extraneousLock):
            #While we can't acquire it, allow other forceCheck: [], async processes to run.
            await sleepAsync(1)

        #log it.
        logger.extraneous.writeLine(statement)

        #Unlock the lock.
        release(logger.extraneousLock)
