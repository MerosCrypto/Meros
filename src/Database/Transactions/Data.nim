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

#Serialization lib.
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
    try:
        result.hash = Blake384(result.serializeHash())
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Data: " & e.msg)

proc newData*(
    sender: EdPublicKey,
    data: string
): Data {.forceCheck: [
    ValueError
].} =
    var input: Hash[384]
    for b in 0 ..< 32:
        input.data[b + 16] = uint8(sender.data[b])

    try:
        result = newData(
            input,
            data
        )
    except ValueError as e:
        fcRaise e

#Sign a Data.
proc sign*(
    wallet: HDWallet,
    data: Data
) {.forceCheck: [].} =
    try:
        data.signature = wallet.sign(data.hash.toString())
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when signing a Data: " & e.msg)

#Mine the Data.
proc mine*(
    data: Data,
    networkDifficulty: Hash[384]
) {.forceCheck: [].} =
    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    var
        proof: uint32 = 0
        hash: ArgonHash = Argon(data.hash.toString(), proof.toBinary().pad(8), true)
    while hash <= networkDifficulty:
        inc(proof)
        hash = Argon(data.hash.toString(), proof.toBinary().pad(8), true)

    try:
        data.proof = proof
        data.argon = hash
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when mining a Data: " & e.msg)
