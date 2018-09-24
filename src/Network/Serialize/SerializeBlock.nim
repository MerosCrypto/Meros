#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Merkle lib.
import ../../../src/lib/Merkle

#Address library.
import ../../Wallet/Address

#Block object.
import ../../Database/Merit/objects/BlockObj

#Serialize/Deserialize functions.
import SerializeCommon
import SerializeMiners

#String utils standard lib.
import strutils

#Serialize a Block.
proc serialize*(blockArg: Block): string {.raises: [ValueError].} =
    #Create the result.
    result =
        #Nonce.
        !blockArg.nonce.toString(256) &
        #Last block.
        !blockArg.last.toBN().toString(256) &
        #Time.
        !blockArg.time.toString(256) &
        #Amount of validations.
        !newBN(blockArg.validations.len).toString(256)

    #Add on each validation.
    for validation in blockArg.validations:
        result &=
            #Address.
            !Address.toBN(validation.validator).toString(256) &
            #Start index.
            !newBN(validation.start).toString(256) &
            #End index.
            !newBN(validation.last).toString(256)

    result &=
        #Merkle Tree root.
        !blockArg.merkle.hash.toBN().toString(256) &
        #Publisher.
        !blockArg.publisher.toBN(16).toString(256)

    if blockArg.signature.len != 0:
        #Proof.
        result &= !blockArg.proof.toString(256)

        #Serialize the miners.
        var minersSerialized = blockArg.miners.serialize(blockArg.nonce)
        result &=
            #Add the miners.
            !minersSerialized &
            #Serialized miners length.
            !newBN(minersSerialized.len - 4).toString(256) &
            #Signature.
            !blockArg.signature.toBN(16).toString(256)
