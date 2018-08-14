#Number libs.
import ../../lib/BN
import ../../lib/Base

#Address library.
import ../../Wallet/Address

#Block object.
import ../../DB/Merit/BlockObj

#Common serialization functions.
import common

proc serialize*(blockArg: Block): string =
    #Create the result.
    result =
        #Last block.
        blockArg.getLast().toBN(16).toString(255) !
        #Nonce.
        blockArg.getNonce().toString(255) !
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
        blockArg.getMerkle().hash.toBN(16).toString(255) !
        #Publisher.
        blockArg.getPublisher().toBN(16).toString(255)

    if not blockArg.getProof().isNil():
        #Add on the proof.
        result &= delim & blockArg.getProof().toBN(16).toString(255)

        for miner in blockArg.getMiners():
            result &= delim &
                Address.toBN(miner.miner).toString(255) !
                $miner.amount
