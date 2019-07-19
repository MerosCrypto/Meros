#Database Testing Functions.

#Errors lib.
import ../../src/lib/Errors

#DB lib.
import ../../src/Database/Filesystem/DB/DB
export DB

#OS standard lib.
import os

#Creates a database.
var db {.threadvar.}: DB
discard existsOrCreateDir("./data")
discard existsOrCreateDir("./data/nim_tests")
proc newTestDatabase*(): DB =
    #Close any existing DB.
    if not db.isNil:
        db.close()

    #Delete any old database.
    removeFile("./data/test" & $getThreadID())

    #Open the database.
    db = newDB("./data/test" & $getThreadID(), 1073741824)
    result = db

#Commit the Database.
proc commit*() =
    db.commit()
