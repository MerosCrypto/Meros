#Numerical libs.
import ../../lib/BN
import ../../lib/Base

#SHA512 lib.
import ../../lib/SHA512

#Errors lib.
import ../../lib/Errors

#Wallet lib.
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize

#Lattice libs.
import objects/NodeObj
import Verification

#MeritRemoval object.
import objects/MeritRemovalObj
export MeritRemovalObj

#Create a new MeritRemoval object.
proc newMeritRemoval*(nonce: BN, first: Verification, second: Verification): MeritRemoval {.raises: [ResultError, ValueError].} =
    #Create the MeritRemoval.
    result = newMeritRemovalObj(first, second)

    #Set the descendant type.
    if not result.setDescendant(3):
        raise newException(ResultError, "Couldn't set the node's descendant type.")

    #Set the nonce.
    if not result.setNonce(nonce):
        raise newException(ResultError, "Couldn't set the Merit Removal nonce.")

    #Set the hash.
    if not result.setHash(SHA512(result.serialize())):
        raise newException(ResultError, "Couldn't set the Merit Removal hash.")

#Sign a MeritRemoval object.
proc sign*(wallet: Wallet, removal: MeritRemoval): bool {.raises: [ValueError].} =
    #Sign the hash of the TX.
    result = removal.setSignature(wallet.sign(removal.getHash()))
