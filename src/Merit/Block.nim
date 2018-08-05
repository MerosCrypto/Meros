#Import the numerical libraries.
import ../lib/BN
import ../lib/Base

#Import the Time library.
import ../lib/Time

#Import the hashing libraries.
import ../lib/SHA512
import ../lib/Argon

#Import the Address library.
import ../Wallet/Address

#Define the Block class.
type Block* = ref object of RootObj
    #Nonce, AKA index.
    nonce: BN
    #Timestamp.
    time: BN
    #Who to attribute the Rep to.
    miner: string
    #Block hash
    hash: string
    #Random hex number to make sure the Argon of the hash is over the difficulty.
    proof: string
    #Argon2d 64 character hash with the hash as the data and proof as the salt.
    argon: string

#New Block function. Makes a new block. Raises an error if there's an issue.
proc newBlock*(nonce: BN, time: BN, miner: string, proof: string): Block {.raises: [ValueError].} =
    #Verify the arguments.
    if Address.verify(miner) == false:
        raise newException(ValueError, "Invalid Address.")
    if proof.isBase(16) == false:
        raise newException(ValueError, "Invalid Hex Number.")

    #Ceate the block.
    result = Block(
        nonce: nonce,
        time: time,
        miner: miner,
        proof: proof
    )

    #Create the hash.
    result.hash = SHA512(
        nonce.toString(16) &
        time.toString(16) &
        miner.substr(3, miner.len).toBN(58).toString(16)
    )

    #Calculate the Argon hash.
    result.argon = Argon(result.hash, result.proof)

#Verify Block function. Creates the block with the passed in arguments and verifies the hashes. Doesn't check its Blockchain validity.
proc verify*(newBlock: Block): bool {.raises: [ValueError].} =
    result = true

    let createdBlock: Block = newBlock(newBlock.nonce, newBlock.time, newBlock.miner, newBlock.proof)
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

proc getMiner*(blockArg: Block): string {.raises: [].} =
    return blockArg.miner

proc getHash*(blockArg: Block): string {.raises: [].} =
    return blockArg.hash

proc getProof*(blockArg: Block): string {.raises: [].} =
    return blockArg.proof

proc getArgon*(blockArg: Block): string {.raises: [].} =
    return blockArg.argon
