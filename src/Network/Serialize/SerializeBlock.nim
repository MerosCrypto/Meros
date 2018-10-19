#Util lib.
import ../../lib/Util

#Base lib.
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Address library.
import ../../Wallet/Address

#Merit objects.
import ../../Database/Merit/objects/MinersObj
import ../../Database/Merit/objects/VerificationsObj
import ../../Database/Merit/objects/BlockObj

#Serialize/Deserialize functions.
import SerializeCommon
import SerializeMiners

#BLS lib.
import BLS

#String utils standard lib.
import strutils

#Serialize a Block.
proc serialize*(blockArg: Block): string {.raises: [ValueError].} =
    #Create the result.
    result =
        #Nonce.
        !blockArg.nonce.toBinary() &
        #Last block.
        !blockArg.last.toString() &
        #Time.
        !blockArg.time.toBinary() &
        #Amount of verifications.
        !blockArg.verifications.verifications.len.toBinary()

    #Add on each verification.
    for verification in blockArg.verifications.verifications:
        result &=
            #Verifier.
            !verification.verifier.toString() &
            #Hash.
            !verification.hash.toString()
    #Add on the BLS sig.
    result &= !blockArg.verifications.aggregate.toString()

    #Publisher.
    result &= !blockArg.publisher.toBN(16).toString(256)

    if blockArg.signature.len != 0:
        #Proof.
        result &= !blockArg.proof.toBinary()

        #Serialize the miners.
        var minersSerialized: string = blockArg.miners.serialize(blockArg.nonce)
        result &=
            #Add the miners.
            !minersSerialized &
            #Serialized miners length.
            !(minersSerialized.len - 11).toBinary() &
            #Signature.
            !blockArg.signature
