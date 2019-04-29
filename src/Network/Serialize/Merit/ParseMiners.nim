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
    BLSError
].} =
    #Quantity | BLS Key 1 | Amount 1 .. BLS Key N | Amount N
    var
        quantity: int = int(minersStr[0])
        minersSeq: seq[string]
        miners: seq[Miner] = newSeq[Miner](quantity)

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
