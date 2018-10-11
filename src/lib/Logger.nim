#Logger. Fully thread safe and non-blocking.

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
proc newLogger*(): Logger {.raises: [Exception].} =
    Logger(
        urgent: open("urgent.log", fmAppend),
        mismatch: open("mismatch.log", fmAppend),
        info: open("info.log", fmAppend),
        extraneous: open("etraneous.log", fmAppend)
    )

#Urgent. Displays a message and halts execution.
proc urgent*(logger: Logger, statement: string) {.raises: [IOerror].} =
    #Print the statement. This will be changed to a dialog box in the future.
    echo statement

    #Log it in a file.
    logger.urgent.writeLine(statement)

    #Quit.
    quit(-1)

#Mismatch. Logs a message worth looking into but doesn't halt execution.
proc mismatch*(logger: Logger, statement: string) {.async.} =
    #Acquire the mismatch lock.
    while not tryAcquire(logger.mismatchLock):
        #While we can't acquire it, allow other async processes to run.
        await sleepAsync(1)

    #log it.
    logger.mismatch.writeLine(statement)

    #Unlock the lock.
    release(logger.mismatchLock)

#Info. Logs a generic message.
proc info*(logger: Logger, statement: string) {.async.} =
    #Acquire the info lock.
    while not tryAcquire(logger.infoLock):
        #While we can't acquire it, allow other async processes to run.
        await sleepAsync(1)

    #log it.
    logger.info.writeLine(statement)

    #Unlock the lock.
    release(logger.infoLock)

#Extranous. Logs a message only worth looking into if you have a rainbow flashes displaying the Star Wars movie.
#Requires debug to be defined.
proc extraneous*(logger: Logger, statement: string) {.async.} =
    #Only do something when debug is defined.
    when defined(debug):
        #Acquire the extraneous lock.
        while not tryAcquire(logger.extraneousLock):
            #While we can't acquire it, allow other async processes to run.
            await sleepAsync(1)

        #log it.
        logger.extraneous.writeLine(statement)

        #Unlock the lock.
        release(logger.extraneousLock)
