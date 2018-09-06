#Numerical libs.
import BN
import ../../lib/Base

#Address library.
import ../../Wallet/Address

#Merkle lib and Block object.
import ../../Database/Merit/Merkle
import ../../Database/Merit/objects/BlockObj

#Common serialization functions and the Miners serialization.
import SerializeCommon
import SerializeMiners

#String utils standard lib.
import strutils

#Serialize a Block.
proc serialize*(blockArg: Block): string =
    #Create the result.
    result =
        #Nonce.
        blockArg.getNonce().toString(255) !
        #Last block.
        blockArg.getLast().toBN(16).toString(255) !
        #Time.
        blockArg.getTime().toString(255) !
        #Amount of validations.
        newBN(blockArg.getValidations().len).toString(255) & delim

    #Add on each validation.
    for validation in blockArg.getValidations():
        result &=
            #Address.
            Address.toBN(validation.validator).toString(255) !
            #Start index.
            newBN(validation.start).toString(255) !
            #End index.
            newBN(validation.last).toString(255) & delim

    result &=
        #Merkle Tree root.
        blockArg.getMerkle().getHash().toBN(16).toString(255) !
        #Publisher.
        blockArg.getPublisher().toBN(16).toString(255)

    if blockArg.getSignature().len != 0:
        result &= delim &
            #Proof.
            blockArg.getProof().toString(255) !
            #Miners.
            blockArg.getMiners().serialize() !
            #Signature.
            blockArg.getSignature().toBN(16).toString(255)

        result = result.toBN(256).toString(253)
