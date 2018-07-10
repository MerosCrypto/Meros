#Import the numerical libraries.
import ../lib/BN
import ../lib/Hex
import ../lib/Base58

#Import the time library.
import ../lib/time

#Import the hashing libraries.
import ../lib/SHA512
import ../lib/Lyra2

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
    #Random hex number to make sure the Lyra of the hash is over the difficulty.
    proof: string
    #Lyra2 64 character hash with the hash as the data and proof as the salt.
    lyra: string

#New Block function. Makes a new block. Raises an error if there's an issue.
proc newBlock*(nonce: BN, time: BN, miner: string, proof: string): Block {.raises: [ValueError, OverflowError, Exception].} =
    #Verify the arguments.
    if Address.verify(miner) == false:
        raise newException(ValueError, "Invalid Address.")
    if Hex.verify(proof) == false:
        raise newException(ValueError, "Invalid Hex Number.")

    #Ceate the block.
    result = Block(
        nonce: nonce,
        time: time,
        miner: miner,
        proof: proof
    )

    #Create the hash.
    result.hash =
        SHA512(
            Hex.convert(nonce)
        ).substr(0, 31) &
        SHA512(
            Hex.convert(time)
        ).substr(32, 63) &
        SHA512(
            Hex.convert(
                Base58.revert(
                    miner.substr(3, miner.len)
                )
            )
        ).substr(64, 127)

    #Calculate the Lyra hash.
    result.lyra = Lyra2(result.hash, result.proof)

#Verify Block function. Creates the block with the passed in arguments and verifies the hashes. Doesn't check its Blockchain validity.
proc verifyBlock*(newBlock: Block): bool {.raises: [ValueError, OverflowError, Exception].} =
    result = true

    var createdBlock: Block = newBlock(newBlock.nonce, newBlock.time, newBlock.miner, newBlock.proof)
    if createdBlock.hash != newBlock.hash:
        result = false
        return

    if createdBlock.lyra != newBlock.lyra:
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

proc getLyra*(blockArg: Block): string {.raises: [].} =
    return blockArg.lyra
