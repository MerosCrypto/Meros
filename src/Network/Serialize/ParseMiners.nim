#Util lib.
import ../../lib/Util

#Numerical libraries.
import BN
import ../../lib/Base

#Address library.
import ../../Wallet/Address

#Common serialization functions.
import SerializeCommon

#String utils standard library.
import strutils

#Parse function.
func parseMiners*(
    minersStr: string
): seq[tuple[miner: string, amount: int]] {.raises: [ValueError].} =
    #Init the result.
    result = @[]

    #Nonce | Address1 | Amount1 .. | AddressN | AmountN
    var minersSeq: seq[string] = minersStr.deserialize(3)

    #Add each miner/amount.
    for i in countup(1, minersSeq.len - 1, 2):
        result.add(
            (
                miner: newAddress(minersSeq[i].pad(32, char(0))),
                amount: int(minersSeq[i + 1][0])
            )
        )
