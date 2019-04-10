#Merit Testing Functions.

#Util lib,
import ../../../src/lib/Util

#MinerWallet lib (for BLSSignature).
import ../../../src/Wallet/MinerWallet

#Hash lib.
import ../../../src/lib/Hash

#Merit lib.
import ../../../src/Database/Merit/Merit

#Serialize libs.
import ../../../src/Network/Serialize/Merit/SerializeDifficulty
import ../../../src/Network/Serialize/Merit/SerializeBlock

#Test Database lib.
import ../TestDatabase
export TestDatabase

#BN lib.
import BN

#Creates a Block, with every setting optional.
proc newTestBlock*(
    nonce: Natural = 0,
    last: ArgonHash = "".pad(48).toArgonHash(),
    aggregate: BLSSignature = nil,
    indexes: seq[VerifierIndex] = @[],
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
        uint(nonce),
        last,
        aggregate,
        indexes,
        miners,
        time,
        proof
    )
