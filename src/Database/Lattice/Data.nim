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
import ../../Network/Serialize/SerializeData

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
    #Set the hash.
    result.sha512 = SHA512(data)

#'Mine' the data (beat the spam filter).
proc mine*(
    data: Data,
    networkDifficulty: BN
) {.raises: [ValueError, ArgonError, FinalAttributeError].} =
    #Create a proof of 0 and get the first Argon hash.
    var
        proof: uint = 0
        hash: ArgonHash = Argon(data.sha512.toString(), proof.toBinary(), true)

    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    while hash.toBN() <= networkDifficulty:
        inc(proof)
        hash = Argon(data.sha512.toString(), proof.toBinary(), true)

    #Set the proof and hash.
    data.proof = proof
    data.hash = hash

#Sign a TX.
func sign*(
    wallet: Wallet,
    data: Data
): bool {.raises: [ValueError, SodiumError, FinalAttributeError].} =
    result = true

    #Make sure the Data was mined.
    if data.hash.toBN() == newBN():
        return false

    #Set the sender behind the Entry.
    data.sender = wallet.address
    #Sign the hash of the Data.
    data.signature = wallet.sign(data.hash.toString())
