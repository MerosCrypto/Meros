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

#Parse function.
proc parseMiners*(
    minersStr: string
): Miners {.raises: [BLSError].} =
    #Quantity | Address1 | Amount1 .. AddressN | AmountN
    var
        quantity: int = int(minersStr[0])
        minersSeq: seq[string]

    #Init the result.
    result = newSeq[Miner](quantity)

    #Parse each Miner.
    for i in 0 ..< quantity:
        minersSeq = minersStr
            .substr(BYTE_LEN + (i * MINER_LEN))
            .deserialize(
                BLS_PUBLIC_KEY_LEN,
                BYTE_LEN
            )

        result[i] = newMinerObj(
            newBLSPublicKey(minersSeq[0]),
            uint(minersSeq[1][0])
        )
