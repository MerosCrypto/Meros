#Database Testing Functions.

#Errors lib.
import ../../src/lib/Errors

#Hash lib.
import ../../src/lib/Hash

#DB lib.
import ../../src/Database/Filesystem/DB/DB
export DB

#Transactions lib.
#import ../../src/Database/Transactions/Transactions

#GlobalFunctionBox.
import ../../src/objects/GlobalFunctionBoxObj
export GlobalFunctionBoxObj

#OS standard lib.
import os

#Create a Database.
var db {.threadvar.}: DB
discard existsOrCreateDir("./data")
discard existsOrCreateDir("./data/NimTests")
proc newTestDatabase*(): DB =
    #Close any existing DB.
    if not db.isNil:
        db.close()

    #Delete any old database.
    removeFile("./data/NimTests/test" & $getThreadID())

    #Open the database.
    db = newDB("./data/NimTests/test" & $getThreadID(), 1073741824)
    result = db

#Commit the Database.
proc commit*(
    blockNum: int
) =
    db.commit(blockNum)

discard """
#Create a GlobalFunctionBox with the needed Transactions functions for Consensus.
var transactions {.threadvar.}: ptr Transactions
proc init*(
    functions: var GlobalFunctionBox,
    transactionsArg: ptr Transactions
) =
    #Save Transactions locally.
    transactions = transactionsArg

    #Create the functions.
    functions.transactions.getTransaction = proc (
        hash: Hash[384]
    ): Transaction =
        transactions[][hash]

    functions.transactions.getSpenders = proc (
        input: Input
    ): seq[Hash[384]] {.inline.} =
        transactions[].loadSpenders(input)

    functions.transactions.verify = proc (
        hash: Hash[384]
    ) =
        discard

    functions.transactions.unverify = proc (
        hash: Hash[384]
    ) =
        discard
"""
