#Errors lib.
import ../../lib/Errors

#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash
#Argon lib.
import ../../lib/Argon

#Wallet libs.
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize/SerializeData

#Node object.
import objects/NodeObj

#Data object.
import objects/DataObj
export DataObj

#Create a new  node.
proc newData*(
    data: seq[uint8],
    nonce: BN
): Data {.raises: [ResultError, ValueError, Exception].} =
    #Verify the data argument.
    if data.len > 1024:
        raise newException(ValueError, "Data data was too long.")

    #Craft the result.
    result = newDataObj(
        data
    )

    #Set the nonce.
    if not result.setNonce(nonce):
        raise newException(ResultError, "Setting the Data nonce failed.")

    #Set the hash.
    if not result.setHash(SHA512(result.serialize())):
        raise newException(ResultError, "Couldn't set the Data hash.")

#'Mine' the data (beat the spam filter).
proc mine*(data: Data, networkDifficulty: BN) {.raises: [ResultError, ValueError].} =
    #Generate proofs until the reduced Argon2 hash beats the difficulty.
    var
        proof: BN = newBN()
        hash: string = "00"

    while hash.toBN(16) < networkDifficulty:
        hash = Argon(data.getSHA512(), proof.toString(16), true)

    if not data.setProof(proof):
        raise newException(ResultError, "Couldn't set the Data proof.")
    if not data.setHash(hash):
        raise newException(ResultError, "Couldn't set the Data hash.")

#Sign a TX.
proc sign*(wallet: Wallet, data: Data): bool {.raises: [ValueError].} =
    result = true

    #Set the sender behind the node.
    if not data.setSender(wallet.getAddress()):
        return false

    #Sign the hash of the Data.
    if not data.setSignature(wallet.sign(data.getHash())):
        return false
