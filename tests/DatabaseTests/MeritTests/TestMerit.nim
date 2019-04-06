#Merit Testing Functions.

#Util lib,
import ../../../src/lib/Util

#BN lib.
import BN

#BLS lib,
import ../../../src/lib/BLS

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

#Creates a Block, with every setting optional.
proc newTestBlock*(
    nonce: int = 0,
    last: ArgonHash = "".pad(48).toArgonHash(),
    aggregate: BLSSignature = nil,
    indexes: seq[VerifierIndex] = @[],
    miners: Miners = @[
        newMinerObj(
            newBLSPrivateKeyFromSeed("TEST").getPublicKey(),
            uint(100)
        )
    ],
    time: uint = getTime(),
    proof: uint = 0
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
