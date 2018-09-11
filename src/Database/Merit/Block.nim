#Errors lib.
import ../../lib/Errors

#Numerical libs.
import BN
import ../../lib/Base

#Time lib.
import ../../lib/Time

#Hash lib.
import ../../lib/Hash
#Argon lib.
import ../../lib/Argon

#Wallet libs.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Serialization lib.
import ../../Network/Serialize/SerializeMiners
import ../../Network/Serialize/SerializeBlock

#Merkle lib and BlockObj.
import Merkle
import objects/BlockObj
#Export the BlockObj.
export BlockObj

#String utils standard library.
import strutils

#New Block function. Creates a new block. Raises an error if there's an issue.
proc newBlock*(
    last: string,
    nonce: BN,
    time: BN,
    validations: seq[tuple[validator: string, start: int, last: int]],
    merkle: MerkleTree,
    publisher: string,
    proof: BN,
    miners: seq[tuple[miner: string, amount: int]],
    signature: string
): Block {.raises: [ResultError, ValueError, Exception].} =
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
    var total: int = 0
    if (miners.len < 1) or (100 < miners.len):
        raise newException(ValueError, "Invalid miners quantity.")
    for miner in miners:
        total += miner.amount
        if not Address.verify(miner.miner):
            raise newException(ValueError, "Invalid miner address.")
        if (miner.amount < 1) or (100 < miner.amount):
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

    if not (
        #Calculate the hash.
        (result.setHash(SHA512(result.serialize()))) and
        #Set the proof.
        (result.setProof(proof)) and
        #Calculate the Argon hash.
        (result.setArgon(Argon(result.getHash(), result.getProof().toString(16))))
    ):
        raise newException(ResultError, "Couldn't set the hash/proof/argon..")

    if not (
        #Set the miners.
        result.setMiners(miners) and
        #Calculate the miners hash.
        result.setMinersHash(SHA512(miners.serialize(nonce)))
    ):
        raise newException(ResultError, "Couldn't set the miners/miners hash..")

    #Verify the signature.
    if not newPublicKey(publisher).verify(result.getMinersHash(), signature):
        raise newException(ValueError, "Invalid miners' signature.")
    #Set the signature.
    if not result.setSignature(signature):
        raise newException(ResultError, "Couldn't set the signature.")
