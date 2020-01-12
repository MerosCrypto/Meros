#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Wallet lib.
import ../../Wallet/Wallet

#Data object.
import objects/DataObj
export DataObj

#Serialization libs.
import ../../Network/Serialize/SerializeCommon
import ../../Network/Serialize/Transactions/SerializeData

#Data constructosr
proc newData*(
    input: Hash[256],
    data: string
): Data {.forceCheck: [
    ValueError
].} =
    #Verify the data length.
    if data.len == 0 or 256 < data.len:
        raise newException(ValueError, "Data is too small or too large.")

    #Create the Data.
    result = newDataObj(
        input,
        data
    )

    #Hash it.
    result.hash = Blake256(result.serializeHash())

#Sign a Data.
proc sign*(
    wallet: HDWallet,
    data: Data
) {.inline, forceCheck: [].} =
    data.signature = wallet.sign(data.hash.toString())

#Mine the Data.
proc mine*(
    data: Data,
    networkDifficulty: Hash[256]
) {.forceCheck: [].} =
    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    var
        proof: uint32 = 0
        hash: ArgonHash = Argon(data.hash.toString(), proof.toBinary(SALT_LEN))
    while hash <= networkDifficulty:
        inc(proof)
        hash = Argon(data.hash.toString(), proof.toBinary(SALT_LEN))

    data.proof = proof
    data.argon = hash
