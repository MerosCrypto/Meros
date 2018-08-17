#Errors lib.
import ../../lib/Errors

#BN lib.
import ../../lib/BN

#SHA512 lib.
import ../../lib/SHA512

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

    if not result.setNonce(nonce):
        raise newException(ResultError, "Setting the Data nonce failed.")

    #Set the hash.
    if not result.setHash(SHA512(result.serialize())):
        raise newException(ResultError, "Couldn't set the Data hash.")

#'Mine' the data (beat the spam filter).
proc mine*(toMine: Data, networkDifficulty: BN) {.raises: [].} =
    #Generate proofs until the SHA512 cubed hash beats the difficulty.
    discard

#Sign a TX.
proc sign*(wallet: Wallet, data: Data): bool {.raises: [ValueError].} =
    #Sign the hash of the TX.
    result = data.setSignature(wallet.sign(data.getHash()))
