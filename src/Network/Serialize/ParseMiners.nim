#Import the numerical libraries.
import ../../lib/BN
import ../../lib/Base

#Import the Address library.
import ../../Wallet/Address

#Common serialization functions.
import common

#String utils standard library.
import strutils

#Parse function.
proc parseMiners*(minersStr: string): seq[tuple[miner: string, amount: int]] =
    #Init the result.
    result = @[]

    var
        #Nonce | Address1 | Amount1 .. | AddressN | AmountN
        minersSeq: seq[string] = minersStr.split(delim)
        #Nonce.
        nonce: BN = minersSeq[0].toBN(255)

    #Add each miner/amount.
    for i in countup(1, minersSeq.len-1, 2):
        result.add(
            (
                miner: newAddress(minersSeq[i].toBN(255).toString(16)),
                amount: minersSeq[i+1].toBN(255).toInt()
            )
        )
