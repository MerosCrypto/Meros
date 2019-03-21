#Provides access to a testing database.

#Errors lib.
import ../../src/lib/Errors

#DB.
import ../../src/Database/Filesystem/DB

#Database Function Box.
import ../../src/objects/GlobalFunctionBoxObj
export DatabaseFunctionBox

#OS standard lib.
import os

#Creates a database.
var db: DB = nil
proc newTestDatabase*(): DatabaseFunctionBox =
    #Close any existing DB.
    if not db.isNil:
        db.close()

    #Delete any old database.
    removeFile("./data/test")

    #Open the database.
    db = newDB("./data/test")

    #Create the Function Box.
    result = DatabaseFunctionBox()

    #Allow access to put/get/delete.
    result.put = proc (key: string, val: string) {.raises: [LMDBError].} =
        try:
            db.put(key, val)
        except:
            raise newException(LMDBError, getCurrentExceptionMsg())

    result.get = proc (key: string): string {.raises: [LMDBError].} =
        try:
            result = db.get(key)
        except:
            raise newException(LMDBError, getCurrentExceptionMsg())

    result.delete = proc (key: string) {.raises: [LMDBError].} =
        try:
            db.delete(key)
        except:
            raise newException(LMDBError, getCurrentExceptionMsg())
