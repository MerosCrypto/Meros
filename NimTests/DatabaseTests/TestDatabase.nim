#Database Testing Functions.

#Errors lib.
import ../../src/lib/Errors

#Hash lib.
import ../../src/lib/Hash

#DB lib.
import ../../src/Database/Filesystem/DB/DB
export DB

#Block and Blockchain libs.
import ../../src/Database/Merit/Block
import ../../src/Database/Merit/Blockchain

#Transactions lib.
import ../../src/Database/Transactions/Transactions

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

#Create a GlobalFunctionBox with the needed functions for Consensus.
var
    blockchain {.threadvar.}: ptr Blockchain
    transactions {.threadvar.}: ptr Transactions
proc newTestGlobalFunctionBox*(
    blockchainArg: ptr Blockchain,
    transactionsArg: ptr Transactions
): GlobalFunctionBox =
    #Save Blockchain/Transactions locally.
    blockchain = blockchainArg
    transactions = transactionsArg

    #Create the functions.
    result = newGlobalFunctionBox()

    result.merit.getHeight = proc (): int {.inline.} =
        blockchain[].height

    result.merit.getBlockByNonce = proc (
        nonce: int
    ): Block =
        blockchain[][nonce]

    result.transactions.getTransaction = proc (
        hash: Hash[384]
    ): Transaction =
        transactions[][hash]

    result.transactions.getSpenders = proc (
        input: Input
    ): seq[Hash[384]] {.inline.} =
        transactions[].loadSpenders(input)

    result.transactions.verify = proc (
        hash: Hash[384]
    ) =
        discard

    result.transactions.unverify = proc (
        hash: Hash[384]
    ) =
        discard
