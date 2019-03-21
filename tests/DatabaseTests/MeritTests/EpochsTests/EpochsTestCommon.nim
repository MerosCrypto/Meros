#Epoch Tests's Common Functions.

#Errors lib.
import ../../../../src/lib/Errors

#Hash lib.
import ../../../../src/lib/Hash

#Wallet lib.
import ../../../../src/Wallet/Wallet

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Test Database lib.
import ../../../lib/TestDatabase
export newTestDatabase

#String utils standard lib.
import strutils

#Generates an empty block.
proc blankBlock*(miners: Miners): Block =
    newBlockObj(
        0,
        char(0).repeat(64).toHash(512),
        nil,
        @[],
        miners
    )
