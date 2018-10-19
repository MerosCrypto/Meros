#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Wallet lib.
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize/SerializeMeritRemoval

#Entry object.
import objects/EntryObj

#MeritRemoval object.
import objects/MeritRemovalObj
export MeritRemovalObj

#Finals lib.
import finals

#Create a new MeritRemoval object.
proc newMeritRemoval*(
    first: Hash[512],
    second: Hash[512],
    nonce: uint
): MeritRemoval {.raises: [ValueError, FinalAttributeError].} =
    #Create the MeritRemoval.
    result = newMeritRemovalObj(first, second)

    #Set the nonce.
    result.nonce = nonce
    #Set the hash.
    result.hash = SHA512(result.serialize())

#Sign a MeritRemoval object.
func sign*(
    wallet: Wallet,
    mr: MeritRemoval
) {.raises: [SodiumError, FinalAttributeError].} =
    #Set the sender behind the Entry.
    mr.sender = wallet.address
    #Sign the hash of the MR.
    mr.signature = wallet.sign(mr.hash.toString())
