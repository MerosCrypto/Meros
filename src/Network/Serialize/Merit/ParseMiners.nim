#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#BLS lib.
import ../../../lib/BLS

#Address library.
import ../../../Wallet/Address

#Miners object.
import ../../../Database/Merit/objects/MinersObj

#Common serialization functions.
import ../SerializeCommon

#String utils standard library.
import strutils

#Parse function.
proc parseMiners*(
    minersStr: string
): Miners {.raises: [BLSError].} =
    #Init the result.
    result = @[]

    #Address1 | Amount1 .. AddressN | AmountN
    var minersSeq: seq[string] = minersStr.deserialize(2)

    #Add each miner/amount.
    for i in countup(0, minersSeq.len - 1, 2):
        result.add(
            newMinerObj(
                newBLSPublicKey(minersSeq[i].pad(48)),
                uint(minersSeq[i + 1].fromBinary())
            )
        )
