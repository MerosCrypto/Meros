#Errors lib.
import ../../lib/Errors

#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize/SerializeData

#Node object.
import objects/NodeObj

#Data object.
import objects/DataObj
export DataObj

#Finals lib.
import finals

#Create a new  node.
proc newData*(
    data: string,
    nonce: BN
): Data {.raises: [ValueError, FinalAttributeError].} =
    #Verify the data argument.
    if data.len > 1024:
        raise newException(ValueError, "Data data was too long.")

    #Craft the result.
    result = newDataObj(
        data
    )
    #Set the nonce.
    result.nonce = nonce
    #Set the hash.
    result.sha512 = SHA512(data)

#'Mine' the data (beat the spam filter).
proc mine*(data: Data, networkDifficulty: BN) {.raises: [ResultError, ValueError, FinalAttributeError].} =
    #Create a proof of 0 and get the first Argon hash.
    var
        proof: BN = newBN()
        hash: ArgonHash = Argon(data.sha512.toString(), proof.toString(256), true)

    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    while hash.toBN() <= networkDifficulty:
        inc(proof)
        hash = Argon(data.sha512.toString(), proof.toString(256), true)

    #Set the proof and hash.
    data.proof = proof
    data.hash = hash

#Sign a TX.
proc sign*(wallet: Wallet, data: Data) {.raises: [FinalAttributeError, Exception].} =
    #Set the sender behind the node.
    data.sender = wallet.address
    #Sign the hash of the Data.
    data.signature = wallet.sign($data.hash)
