#Import the numerical libraries.
import ../../lib/BN
import ../../lib/Base

#Import the Address library.
import ../../Wallet/Address

#Common serialization functions.
import common

#String utils standard library.
import strutils

#Serialization function.
proc serialize*(miners: seq[tuple[miner: string, amount: int]], nonce: BN = nil): string =
    #Create the result.
    if nonce.isNil:
        result = ""
    else:
        result = nonce.toString(255) & delim

    #Add each miner.
    for miner in 0 ..< miners.len:
        result &=
            Address.toBN(miners[miner].miner).toString(255) !
            miners[miner].amount.toHex().toBN(16).toString(255)

        #Don't add the delimiter to the end of the string.
        if miner != (miners.len - 1):
            result &= delim
