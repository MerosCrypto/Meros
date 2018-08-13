#Import the numerical libraries.
import ../../lib/BN
import ../../lib/Base

#Import the Time library.
import ../../lib/Time

#Import the hashing libraries.
import ../../lib/SHA512
import ../../lib/Argon

#Import the Address library.
import ../../Wallet/Address

#Import the Merkle library.
import Merkle

#String utils standard library.
import strutils

#Define the Block class.
type Block* = ref object of RootObj
    #Nonce, AKA index.
    nonce: BN
    #Timestamp.
    time: BN
    #Validations.
    validations: seq[tuple[validator: string, start: int, last: int]]
    #Merkle tree.
    merkle: MerkleTree
    #Hash.
    hash: string
    #Random hex number to make sure the Argon of the hash is over the difficulty.
    proof: string
    #Argon2d 64 character hash with the hash as the data and proof as the salt.
    argon: string
    #Who to attribute the Merit to.
    miners: seq[tuple[miner: string, percent: float]]

proc serialize*(blockArg: Block, mined: bool = false): string =
    var delim: string = $((char) 0)

    result =
        blockArg.nonce.toString(255) & delim &
        blockArg.time.toString(255) & delim &
        newBN(blockArg.validations.len).toString(255) & delim

    for validation in blockArg.validations:
        result = result &
            Address.toBN(validation.validator).toString(255) & delim &
            newBN(validation.start).toString(255) & delim &
            newBN(validation.last).toString(255) & delim

    result = result & blockArg.merkle.hash.toBN(16).toString(255)

    if mined:
        result = result & delim &
            blockArg.proof.toBN(16).toString(255)

        for miner in blockArg.miners:
            result = result & delim &
                Address.toBN(miner.miner).toString(255) & delim &
                $miner.percent

#New Block function. Makes a new block. Raises an error if there's an issue.
proc newBlock*(
    nonce: BN,
    time: BN,
    validations: seq[tuple[validator: string, start: int, last: int]],
    merkle: MerkleTree,
    proof: string,
    miners: seq[tuple[miner: string, percent: float]]
): Block {.raises: [ValueError].} =
    #Verify the arguments.
    for validation in validations:
        if Address.verify(validation.validator) == false:
            raise newException(ValueError, "Invalid Address.")
        if validation.start < 0:
            raise newException(ValueError, "Invalid Start.")
        if validation.last < 0:
            raise newException(ValueError, "Invalid Last.")

    if proof.isBase(16) == false:
        raise newException(ValueError, "Invalid Hex Number.")

    for miner in miners:
        if Address.verify(miner.miner) == false:
            raise newException(ValueError, "Invalid Address.")
        if (miner.percent < 0.1) or (100 < miner.percent):
            raise newException(ValueError, "Invalid Percent.")

    #Ceate the block.
    result = Block(
        nonce: nonce,
        time: time,
        validations: validations,
        merkle: merkle,
        proof: proof,
        miners: miners
    )

    #Create the hash.
    result.hash = SHA512(result.serialize())

    #Calculate the Argon hash.
    result.argon = Argon(result.hash, result.proof)

#Verify Block function. Creates the block with the passed in arguments and verifies the hashes. Doesn't check its Blockchain validity.
proc verify*(newBlock: Block): bool {.raises: [ValueError].} =
    result = true

    let createdBlock: Block = newBlock(
        newBlock.nonce,
        newBlock.time,
        newBlock.validations,
        newBlock.merkle,
        newBlock.proof,
        newBlock.miners
    )
    if createdBlock.hash != newBlock.hash:
        result = false
        return

    if createdBlock.argon != newBlock.argon:
        result = false
        return

#Getters.
proc getNonce*(blockArg: Block): BN {.raises: [].} =
    return blockArg.nonce

proc getTime*(blockArg: Block): BN {.raises: [].} =
    return blockArg.time

proc getValidations*(blockArg: Block): seq[tuple[validator: string, start: int, last: int]] {.raises: [].} =
    return blockArg.validations

proc getMerkle*(blockArg: Block): MerkleTree {.raises: [].} =
    return blockArg.merkle

proc getHash*(blockArg: Block): string {.raises: [].} =
    return blockArg.hash

proc getProof*(blockArg: Block): string {.raises: [].} =
    return blockArg.proof

proc getArgon*(blockArg: Block): string {.raises: [].} =
    return blockArg.argon

proc getMiners*(blockArg: Block): seq[tuple[miner: string, percent: float]] {.raises: [].} =
    return blockArg.miners
