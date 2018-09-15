#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Wallet lib.
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize/SerializeMeritRemoval

#Node object.
import objects/NodeObj

#MeritRemoval object.
import objects/MeritRemovalObj
export MeritRemovalObj

#SetOnce lib.
import SetOnce

#Create a new MeritRemoval object.
proc newMeritRemoval*(first: Hash[512], second: Hash[512], nonce: BN): MeritRemoval {.raises: [ValueError, Exception].} =
    #Create the MeritRemoval.
    result = newMeritRemovalObj(first, second)
    #Set the nonce.
    result.nonce.value = nonce
    #Set the hash.
    result.hash.value = SHA512(result.serialize())

#Sign a MeritRemoval object.
proc sign*(wallet: Wallet, mr: MeritRemoval) {.raises: [ValueError].} =
    #Set the sender behind the node.
    mr.sender.value = wallet.address
    #Sign the hash of the MR.
    mr.signature.value = wallet.sign($mr.hash.toValue())
