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
    input: Hash[384],
    data: string
): Data {.forceCheck: [
    ValueError
].} =
    #Verify the data length.
    if data.len < 1 or 255 < data.len:
        raise newException(ValueError, "Data is too small or too large.")

    #Create the Data.
    result = newDataObj(
        input,
        data
    )

    #Hash it.
    result.hash = Blake384(result.serializeHash())

    #Verify the Data's hash doesn't start with 16 zeroes.
    for b in 0 ..< 16:
        if result.hash.data[b] != 0:
            break
        if b == 15:
            raise newException(ValueError, "Data's hash starts with 16 0s.")

#Sign a Data.
proc sign*(
    wallet: HDWallet,
    data: Data
) {.inline, forceCheck: [].} =
    data.signature = wallet.sign(data.hash.toString())

#Mine the Data.
proc mine*(
    data: Data,
    networkDifficulty: Hash[384]
) {.forceCheck: [].} =
    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    var
        proof: uint32 = 0
        hash: ArgonHash = Argon(data.hash.toString(), proof.toBinary(SALT_LEN), true)
    while hash <= networkDifficulty:
        inc(proof)
        hash = Argon(data.hash.toString(), proof.toBinary(SALT_LEN), true)

    data.proof = proof
    data.argon = hash
