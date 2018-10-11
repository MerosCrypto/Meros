#Util lib.
import ../../lib/Util

#Base lib.
import ../../lib/Base

#Import the Address library.
import ../../Wallet/Address

#Miners object.
import ../../Database/Merit/objects/MinersObj

#Common serialization functions.
import SerializeCommon

#String utils standard library.
import strutils

#Serialization function.
proc serialize*(
    miners: Miners,
    nonce: uint
): string {.raises: [ValueError].} =
    #Create the result.
    result = !nonce.toBinary()

    #Add each miner.
    for miner in 0 ..< miners.len:
        result &=
            !Address.toBN(miners[miner].miner).toString(256) &
            char(1) & char(miners[miner].amount)
