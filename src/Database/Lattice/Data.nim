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

#SetOnce lib.
import SetOnce

#Create a new  node.
proc newData*(
    data: seq[uint8],
    nonce: BN
): Data {.raises: [ValueError, Exception].} =
    #Verify the data argument.
    if data.len > 1024:
        raise newException(ValueError, "Data data was too long.")

    #Craft the result.
    result = newDataObj(
        data
    )

    #Set the nonce.
    result.nonce.value = nonce

    #Set the hash.
    result.hash.value = SHA512(result.serialize())

#'Mine' the data (beat the spam filter).
proc mine*(data: Data, networkDifficulty: BN) {.raises: [ResultError, ValueError].} =
    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    var
        proof: BN = newBN()
        hash: ArgonHash = Argon(data.sha512, proof.toString(256), true)

    while hash.toBN() <= networkDifficulty:
        inc(proof)
        hash = Argon(data.sha512, proof.toString(256), true)

    data.proof.value = proof
    data.hash.value = hash

#Sign a TX.
proc sign*(wallet: Wallet, data: Data) {.raises: [ValueError].} =
    #Set the sender behind the node.
    data.sender.value = wallet.address
    #Sign the hash of the Data.
    data.signature.value = wallet.sign($data.hash.toValue())
