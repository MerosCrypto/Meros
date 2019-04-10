#Database Testing Functions.

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
    db = newDB("./data/test", 1073741824)

    #Create the Function Box.
    result = DatabaseFunctionBox()

    #Allow access to put/get/delete.
    result.put = proc (key: string, val: string) {.raises: [DBWriteError].} =
        try:
            db.put(key, val)
        except Exception as e:
            raise newException(DBWriteError, e.msg)

    result.get = proc (key: string): string {.raises: [DBReadError].} =
        try:
            result = db.get(key)
        except Exception as e:
            raise newException(DBReadError, e.msg)

    result.delete = proc (key: string) {.raises: [DBWriteError].} =
        try:
            db.delete(key)
        except Exception as e:
            raise newException(DBWriteError, e.msg)
