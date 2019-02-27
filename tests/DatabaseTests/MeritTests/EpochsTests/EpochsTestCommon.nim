#Epoch Tests's Common Functions.

#Errors lib.
import ../../../../src/lib/Errors

#Hash lib.
import ../../../../src/lib/Hash

#Wallet lib.
import ../../../../src/Wallet/Wallet

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Database Function Box.
import ../../../../src/objects/GlobalFunctionBoxObj

#DB.
import ../../../../src/Database/Filesystem/DB

#String utils standard lib.
import strutils

#Creates a database.
var db: DB
proc newTestDatabase*(): DatabaseFunctionBox =
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

#Generates an empty block.
proc blankBlock*(miners: Miners): Block =
    newBlockObj(
        0,
        char(0).repeat(64).toHash(512),
        nil,
        @[],
        miners
    )
