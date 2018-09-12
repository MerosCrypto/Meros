#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Errors lib.
import ../../lib/Errors

#Wallet lib.
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize/SerializeMeritRemoval

#Node object.
import objects/NodeObj

#MeritRemoval object.
import objects/MeritRemovalObj
export MeritRemovalObj

#Create a new MeritRemoval object.
proc newMeritRemoval*(first: string, second: string, nonce: BN): MeritRemoval {.raises: [ResultError, ValueError, Exception].} =
    #Create the MeritRemoval.
    result = newMeritRemovalObj(first, second)

    #Set the nonce.
    if not result.setNonce(nonce):
        raise newException(ResultError, "Couldn't set the Merit Removal nonce.")

    #Set the hash.
    if not result.setHash(SHA512(result.serialize())):
        raise newException(ResultError, "Couldn't set the Merit Removal hash.")

#Sign a MeritRemoval object.
proc sign*(wallet: Wallet, mr: MeritRemoval): bool {.raises: [ValueError].} =
    result = true

    #Set the sender behind the node.
    if not mr.setSender(wallet.getAddress()):
        return false

    #Sign the hash of the MR.
    if not mr.setSignature(wallet.sign($mr.getHash())):
        return false
