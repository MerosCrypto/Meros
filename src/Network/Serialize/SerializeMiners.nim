#Util lib.
import ../../lib/Util

#Miners object.
import ../../Database/Merit/objects/MinersObj

#Common serialization functions.
import SerializeCommon

#BLS lib.
import BLS

#String utils standard library.
import strutils

#Serialization function.
proc serialize*(
    miners: Miners,
    nonce: uint
): string {.raises: [].} =
    #Create the result.
    result = !nonce.toBinary()

    #Add each miner.
    for miner in 0 ..< miners.len:
        result &=
            !miners[miner].miner.toString() &
            char(1) & char(miners[miner].amount)
