#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Miners object.
import ../../../Database/Merit/objects/MinersObj

#Common serialization functions.
import ../SerializeCommon

#MinerWallet lib (for BLSPublicKey's toString).
import ../../../Wallet/MinerWallet

#Serialization function.
func serialize*(
    miners: Miners
): string {.forceCheck: [].} =
    #Set the quantity.
    result = $char(miners.miners.len)

    #Add each miner.
    for m in 0 ..< miners.miners.len:
        result &=
            miners.miners[m].miner.toString() &
            char(miners.miners[m].amount)
