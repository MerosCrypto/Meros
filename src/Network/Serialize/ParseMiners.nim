#Util lib.
import ../../lib/Util

#Address library.
import ../../Wallet/Address

#Miners object.
import ../../Database/Merit/objects/MinersObj

#Common serialization functions.
import SerializeCommon

#String utils standard library.
import strutils

#Parse function.
func parseMiners*(
    minersStr: string
): Miners {.raises: [ValueError].} =
    #Init the result.
    result = @[]

    #Nonce | Address1 | Amount1 .. | AddressN | AmountN
    var minersSeq: seq[string] = minersStr.deserialize(3)

    #Add each miner/amount.
    for i in countup(1, minersSeq.len - 1, 2):
        result.add(
            newMinerObj(
                newAddress(minersSeq[i].pad(32, char(0))),
                uint(minersSeq[i + 1][0])
            )
        )
