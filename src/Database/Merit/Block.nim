#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Numerical libs.
import BN
import ../../lib/Base

#Hash lib.
import ../../lib/Hash

#Merkle lib.
import ../../lib/Merkle

#Wallet libs.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Serialization lib.
import ../../Network/Serialize/SerializeMiners
import ../../Network/Serialize/SerializeBlock

#BlockObj.
import objects/BlockObj
#Export the BlockObj.
export BlockObj

#Finals lib.
import finals

#String utils standard library.
import strutils

#New Block function. Creates a new block. Raises an error if there's an issue.
proc newBlock*(
    last: ArgonHash,
    nonce: int,
    time: uint,
    validations: seq[tuple[validator: string, start: uint, last: uint]],
    merkle: MerkleTree,
    publisher: string,
    proof: uint,
    miners: seq[tuple[miner: string, amount: uint]],
    signature: string
): Block {.raises: [
    ValueError,
    ArgonError,
    SodiumError,
    FinalAttributeError
].} =
    #Verify the arguments.
    #Validations.
    for validation in validations:
        if not Address.verify(validation.validator):
            raise newException(ValueError, "Invalid validation address.")
        if validation.start < 0:
            raise newException(ValueError, "Invalid validation start.")
        if validation.last < 0:
            raise newException(ValueError, "Invalid validation last.")

    #Miners.
    var total: uint = 0
    if (miners.len < 1) or (100 < miners.len):
        raise newException(ValueError, "Invalid miners quantity.")
    for miner in miners:
        total += miner.amount
        if not Address.verify(miner.miner):
            raise newException(ValueError, "Invalid miner address.")
        if (miner.amount < 1) or (uint(100) < miner.amount):
            raise newException(ValueError, "Invalid miner amount.")
    if total != 100:
        raise newException(ValueError, "Invalid total miner amount.")

    #Ceate the block.
    result = newBlockObj(
        last,
        nonce,
        time,
        validations,
        merkle,
        publisher
    )

    #Calculate the hash.
    result.hash = SHA512(result.serialize())
    #Set the proof.
    result.proof = proof
    #Calculate the Argon hash.
    result.argon = Argon(result.hash.toString(), newBN(result.proof).toString(256))

    #Set the miners.
    result.miners = miners
    #Calculate the miners hash.
    result.minersHash = SHA512(miners.serialize(nonce))
    #Verify the signature.
    if not publisher.newPublicKey().verify(result.minersHash.toString(), signature):
        raise newException(ValueError, "Invalid miners' signature.")
    #Set the signature.
    result.signature = signature
