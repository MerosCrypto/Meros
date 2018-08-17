#Errors lib.
import ../../lib/Errors

#Numerical libs.
import ../../lib/BN
import ../../lib/Base

#Hashing libs.
import ../../lib/SHA512
import ../../lib/Argon

#Wallet libs.
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize

#Node object.
import objects/NodeObj

#Data object.
import objects/DataObj
export DataObj

#Create a new  node.
proc newData*(
    data: seq[uint8],
    nonce: BN
): Data {.raises: [ResultError, ValueError].} =
    #Verify the data argument.
    if data.len > 1024:
        raise newException(ValueError, "Data data was too long.")

    #Craft the result.
    result = newDataObj(
        data
    )

    #Set the descendant type.
    if not result.setDescendant(2):
        raise newException(ResultError, "Couldn't set the node's descendant type.")

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

    if data.setProof(proof) == false:
        raise newException(ResultError, "Couldn't set the Data proof.")
    if data.setHash(hash) == false:
        raise newException(ResultError, "Couldn't set the Data hash.")

#Sign a TX.
proc sign*(wallet: Wallet, data: Data): bool {.raises: [ValueError].} =
    #Sign the hash of the TX.
    result = data.setSignature(wallet.sign(data.getHash()))
