#Import the numerical libraries.
import ../../lib/BN
import ../../lib/Base

#Import the Time library.
import ../../lib/Time

#Import the hashing libraries.
import ../../lib/SHA512
import ../../lib/Argon

#Import the Wallet libraries.
import ../../Wallet/Address
import ../../Wallet/Wallet

#Import the Serialization library.
import ../../Network/Serialize

#Import the Merkle library and BlockObj.
import Merkle
import BlockObj
#Export the BlockObj.
export BlockObj

#String utils standard library.
import strutils

#Block 0 function. Creates a new block without caring about the data.
proc newStartBlock*(genesis: string): Block {.raises: [ValueError, AssertionError].} =
    #Ceate the block.
    result = newBlockObj(
        newBN(),
        getTime(),
        @[],
        newMerkleTree(@[]),
        "",
        "00",
        @[],
        ""
    )
    #Calculate the hash.
    result.setHash(SHA512(genesis))
    #Calculate the Argon hash.
    result.setArgon(Argon(result.getHash(), result.getProof()))
    #Calculate the miners hash.
    result.setMinersHash(SHA512($((char) 0)))

#New Block function. Creates a new block. Raises an error if there's an issue.
proc newBlock*(
    nonce: BN,
    time: BN,
    validations: seq[tuple[validator: string, start: int, last: int]],
    merkle: MerkleTree,
    publisher: string,
    proof: string,
    miners: seq[tuple[miner: string, percent: int]],
    signature: string
): Block {.raises: [ValueError].} =
    #Verify the arguments.
    #Validations.
    for validation in validations:
        if Address.verify(validation.validator) == false:
            raise newException(ValueError, "Invalid address.")
        if validation.start < 0:
            raise newException(ValueError, "Invalid start.")
        if validation.last < 0:
            raise newException(ValueError, "Invalid last.")
    #Proof.
    if proof.isBase(16) == false:
        raise newException(ValueError, "Invalid hex number.")
    #Miners.
    var
        total: int = 0
    for miner in miners:
        total += miner.percent
        if Address.verify(miner.miner) == false:
            raise newException(ValueError, "Invalid address.")
        if (miner.percent < 1) or (1000 < miner.percent):
            raise newException(ValueError, "Invalid percent.")
    if total != 1000:
        raise newException(ValueError, "Invalid total percent.")

    #Ceate the block.
    result = newBlockObj(
        nonce,
        time,
        validations,
        merkle,
        publisher,
        proof,
        miners,
        signature
    )
    #Calculate the hash.
    result.setHash(SHA512(result.serialize()))
    #Calculate the Argon hash.
    result.setArgon(Argon(result.getHash(), result.getProof()))
    #Calculate the miners hash.
    result.setMinersHash(SHA512(miners.serialize(nonce)))
    #Verify the signature.
    if not newPublicKey(publisher).verify(result.getMinersHash(), signature):
        raise newException(ValueError, "Invalid miners' signature.")
