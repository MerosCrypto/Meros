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

#Finals lib.
import finals

#Create a new MeritRemoval object.
proc newMeritRemoval*(
    first: Hash[512],
    second: Hash[512],
    nonce: BN
): MeritRemoval {.raises: [ValueError, FinalAttributeError].} =
    #Create the MeritRemoval.
    result = newMeritRemovalObj(first, second)

    #Set the nonce.
    result.nonce = nonce
    #Set the hash.
    result.hash = SHA512(result.serialize())

#Sign a MeritRemoval object.
proc sign*(wallet: Wallet, mr: MeritRemoval) {.raises: [FinalAttributeError, Exception].} =
    #Set the sender behind the node.
    mr.sender = wallet.address
    #Sign the hash of the MR.
    mr.signature = wallet.sign($mr.hash)
