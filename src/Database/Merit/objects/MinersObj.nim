#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib (used for BLSPublicKey).
import ../../../Wallet/MinerWallet

#Merkle lib.
import ../../common/Merkle

#Finals lib.
import finals

finalsd:
    type
        #Miner object.
        Miner* = object
            miner* {.final.}: BLSPublicKey
            amount* {.final.}: Natural

        #Miners object.
        Miners* = object
            miners*: seq[Miner]
            merkle*: Merkle

#Miner Constructor.
func newMinerObj*(
    miner: BLSPublicKey,
    amount: Natural
): Miner {.forceCheck: [].} =
    result = Miner(
        miner: miner,
        amount: amount
    )
    result.ffinalizeMiner()
    result.ffinalizeAmount()

#Miners Constructor.
proc newMinersObj*(
    miners: seq[Miner] = @[]
): Miners {.forceCheck: [].} =
    #Create the Miners object.
    result = Miners(
        miners: miners
    )

    #Create a Markle Tree of the Miners.
    var hashes: seq[Blake384Hash] = newSeq[Blake384Hash](miners.len)
    for i in 0 ..< miners.len:
        hashes[i] = Blake384(
            miners[i].miner.toString() &
            miners[i].amount.toBinary()
        )
    result.merkle = newMerkle(hashes)

#Adds a new Miner to Miners.
proc add*(
    miners: var Miners,
    miner: Miner
) {.forceCheck: [].} =
    miners.miners.add(miner)
    miners.merkle.add(
        Blake384(
            miner.miner.toString() &
            miner.amount.toBinary()
        )
    )
