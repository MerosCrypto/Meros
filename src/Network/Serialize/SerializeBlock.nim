#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Address library.
import ../../Wallet/Address

#Merkle lib and Block object.
import ../../Database/Merit/Merkle
import ../../Database/Merit/objects/BlockObj

#Common serialization functions and the Miners serialization.
import SerializeCommon
import SerializeMiners

#SetOnce lib.
import SetOnce

#String utils standard lib.
import strutils

#Serialize a Block.
proc serialize*(blockArg: Block): string {.raises: [ValueError, Exception].} =
    #Create the result.
    result =
        #Nonce.
        blockArg.nonce.toString(255) !
        #Last block.
        blockArg.last.toBN().toString(255) !
        #Time.
        blockArg.time.toString(255) !
        #Amount of validations.
        newBN(blockArg.validations.len).toString(255) & delim

    #Add on each validation.
    for validation in blockArg.validations:
        result &=
            #Address.
            Address.toBN(validation.validator).toString(255) !
            #Start index.
            newBN(validation.start).toString(255) !
            #End index.
            newBN(validation.last).toString(255) & delim

    result &=
        #Merkle Tree root.
        blockArg.merkle.hash.toBN().toString(255) !
        #Publisher.
        blockArg.publisher.toBN(16).toString(255)

    if blockArg.signature.len != 0:
        result &= delim &
            #Proof.
            blockArg.proof.toString(255) !
            #Miners.
            blockArg.miners.serialize() !
            #Signature.
            blockArg.signature.toBN(16).toString(255)

        result = result.toBN(256).toString(253)
