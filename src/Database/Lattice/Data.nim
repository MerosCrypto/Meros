#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize/Lattice/SerializeData

#Entry object.
import objects/EntryObj

#Data object.
import objects/DataObj
export DataObj

#Create a new Entry.
proc newData*(
    data: string,
    nonce: Natural
): Data {.forceCheck: [
    ValueError
].} =
    #Verify the data argument.
    if data.len > 255:
        raise newException(ValueError, "Data's data was greater than 255 bytes.")

    #Create the result.
    result = newDataObj(
        data
    )

    #Set the nonce.
    try:
        result.nonce = nonce
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Data: " & e.msg)

#Sign a TX.
proc sign*(
    wallet: Wallet,
    data: Data
) {.forceCheck: [
    AddressError,
    SodiumError
].} =
    try:
        #Set the sender behind the Entry.
        data.sender = wallet.address
        #Set the hash.
        data.hash = Blake384(data.serialize())
        #Sign the hash of the Data.
        data.signature = wallet.sign(data.hash.toString())
        data.signed = true
    except AddressError as e:
        fcRaise e
    except SodiumError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when signing a Data: " & e.msg)

#'Mine' the data (beat the spam filter).
proc mine*(
    data: Data,
    networkDifficulty: Hash[384]
) {.forceCheck: [
    ValueError,
    ArgonError
].} =
    #Make sure the hash was set.
    if not data.signed:
        raise newException(ValueError, "Data wasn't signed.")

    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    var
        proof: int = 0
        hash: ArgonHash
    try:
        hash = Argon(data.hash.toString(), proof.toBinary(), true)
        while hash <= networkDifficulty:
            inc(proof)
            hash = Argon(data.hash.toString(), proof.toBinary(), true)
    except ArgonError as e:
        fcRaise e

    try:
        data.proof = proof
        data.argon = hash
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when mining a Send: " & e.msg)
