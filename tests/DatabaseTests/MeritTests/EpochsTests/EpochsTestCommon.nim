#Epoch Tests's Common Functions.

#Hash lib.
import ../../../../src/lib/Hash

#Wallet lib.
import ../../../../src/Wallet/Wallet

#Merit lib.
import ../../../../src/Database/Merit/Merit

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
