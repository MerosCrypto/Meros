#Merit Testing Functions.

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib (for BLSSignature).
import ../../../src/Wallet/MinerWallet

#MeritHolderRecord object.
import ../../../src/Database/common/objects/MeritHolderRecordObj

#Merit lib.
import ../../../src/Database/Merit/Merit

#Test Database lib.
import ../TestDatabase
export TestDatabase

#Create a Block, with every setting optional.
proc newBlankBlock*(
    nonce: Natural = 0,
    last: ArgonHash = "".pad(48).toArgonHash(),
    aggregate: BLSSignature = nil,
    records: seq[MeritHolderRecord] = @[],
    miners: Miners = newMinersObj(@[
        newMinerObj(
            newBLSPrivateKeyFromSeed("TEST").getPublicKey(),
            uint(100)
        )
    ]),
    time: int64 = getTime(),
    proof: Natural = 0
): Block =
    newBlockObj(
        nonce,
        last,
        aggregate,
        records,
        miners,
        time,
        proof
    )
