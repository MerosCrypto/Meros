#Merit Testing Functions.

#Util lib,
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib (for BLSSignature).
import ../../../src/Wallet/MinerWallet

#VerifierRecord object.
import ../../../src/Database/common/objects/VerifierRecordObj

#Merit lib.
import ../../../src/Database/Merit/Merit

#Serialize libs.
import ../../../src/Network/Serialize/Merit/SerializeDifficulty
import ../../../src/Network/Serialize/Merit/SerializeBlock

#Test Database lib.
import ../TestDatabase
export TestDatabase

#Creates a Block, with every setting optional.
proc newTestBlock*(
    nonce: Natural = 0,
    last: ArgonHash = "".pad(48).toArgonHash(),
    aggregate: BLSSignature = nil,
    records: seq[VerifierRecord] = @[],
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
