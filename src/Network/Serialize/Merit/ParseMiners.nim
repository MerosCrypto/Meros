#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#MinerWallet lib (for BLSPublicKey).
import ../../../Wallet/MinerWallet

#Miners object.
import ../../../Database/Merit/objects/MinersObj

#Common serialization functions.
import ../SerializeCommon

#Parse function.
proc parseMiners*(
    minersStr: string
): Miners {.forceCheck: [
    ValueError,
    BLSError
].} =
    #Quantity | BLS Key 1 | Amount 1 .. BLS Key N | Amount N
    var
        quantity: int
        minersSeq: seq[string]
        miners: seq[Miner]

    try:
        quantity = int(minersStr[0])
    except IndexError as e:
        raise newException(ValueError, "parseMiners not handed enough data to get the quantity: " & e.msg)
    miners = newSeq[Miner](quantity)

    #Parse each Miner.
    for i in 0 ..< quantity:
        minersSeq = minersStr
            .substr(BYTE_LEN + (i * MINER_LEN))
            .deserialize(
                BLS_PUBLIC_KEY_LEN,
                BYTE_LEN
            )

        try:
            miners[i] = newMinerObj(
                newBLSPublicKey(minersSeq[0]),
                int(minersSeq[1][0])
            )
        except BLSError as e:
            fcRaise e

    result = newMinersObj(miners)
