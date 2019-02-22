#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#BNl lib.
import BN

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

#Finals lib.
import finals

#Create a new Entry.
proc newData*(
    data: string,
    nonce: uint
): Data {.raises: [ValueError, FinalAttributeError].} =
    #Verify the data argument.
    if data.len > 256:
        raise newException(ValueError, "Data's data was greater than 1/4 KB..")

    #Craft the result.
    result = newDataObj(
        data
    )
    #Set the nonce.
    result.nonce = nonce

#Sign a TX.
proc sign*(
    wallet: Wallet,
    data: Data
){.raises: [ValueError, SodiumError, FinalAttributeError].} =
    #Set the sender behind the Entry.
    data.sender = wallet.address
    #Set the hash.
    data.hash = Blake512(data.serialize())
    #Sign the hash of the Data.
    data.signature = wallet.sign(data.hash.toString())

#'Mine' the data (beat the spam filter).
proc mine*(
    data: Data,
    networkDifficulty: BN
) {.raises: [ValueError, ArgonError, FinalAttributeError].} =
    #Make sure the hash was set.
    if data.hash.toBN() == newBN():
        raise newException(ValueError, "Data wasn't signed.")

    #Create a proof of 0 and get the first Argon hash.
    var
        proof: uint = 0
        hash: ArgonHash = Argon(data.hash.toString(), proof.toBinary(), true)

    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    while hash.toBN() <= networkDifficulty:
        inc(proof)
        hash = Argon(data.hash.toString(), proof.toBinary(), true)

    #Set the proof and hash.
    data.proof = proof
    data.argon = hash
