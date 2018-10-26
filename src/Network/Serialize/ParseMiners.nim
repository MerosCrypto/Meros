#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Address library.
import ../../Wallet/Address

#Miners object.
import ../../Database/Merit/objects/MinersObj

#Common serialization functions.
import SerializeCommon

#BLS lib.
import ../../lib/BLS

#String utils standard library.
import strutils

#Parse function.
proc parseMiners*(
    minersStr: string
): Miners {.raises: [BLSError].} =
    #Init the result.
    result = @[]

    #Nonce | Address1 | Amount1 .. | AddressN | AmountN
    var minersSeq: seq[string] = minersStr.deserialize(3)

    #Add each miner/amount.
    for i in countup(1, minersSeq.len - 1, 2):
        #Create the Public Key.
        var key: BLSPublicKey = newBLSPublicKey(minersSeq[i])

        result.add(
            newMinerObj(
                key,
                uint(minersSeq[i + 1][0])
            )
        )
