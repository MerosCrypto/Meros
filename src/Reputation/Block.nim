#Import the numerical libraries.
import ../lib/BN
import ../lib/Hex
import ../lib/Base58

#Import the time library.
import ../lib/time

#Import the hashing libraries.
import ../lib/SHA512
import ../lib/Lyra2

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
proc newBlock*(nonce: BN, time: BN, miner: string, proof: string): Block =
    #vErify the arguments.
    Base58.verify(miner)
    Hex.verify(proof)

    #Ceate the block.
    result = Block(
        nonce: nonce,
        time: time,
        miner: miner,
        proof: proof
    )

    #Create the hash.
    result.hash = SHA512(Hex.convert(nonce)).substr(0, 31) &
        SHA512(Hex.convert(time)).substr(32, 63) &
        SHA512(Hex.convert(Base58.revert(miner))).substr(64, 127)
    #Calculate the Lyra hash.
    result.lyra = Lyra2(result.hash, result.proof)

#Create Block function that just uses the current time.
proc newBlock*(nonce: BN, miner: string, proof: string): Block =
    result = newBlock(nonce, getTime(), miner, proof)

#Verify Block function. Creates the block with the passed in arguments and verifies the hashes. Doesn't check its Blockchain validity.
proc verifyBlock*(newBlock: Block) =
    var createdBlock: Block = newBlock(newBlock.nonce, newBlock.time, newBlock.miner, newBlock.proof)
    if createdBlock.hash != newBlock.hash:
        raise newException(Exception, "Invalid hash")

    if createdBlock.lyra != newBlock.lyra:
        raise newException(Exception, "Invalid lyra")

#Getters.
proc getNonce*(blockObj: Block): BN =
    return blockObj.nonce

proc getTime*(blockObj: Block): BN =
    return blockObj.time

proc getMiner*(blockObj: Block): string =
    return blockObj.miner

proc getHash*(blockObj: Block): string =
    return blockObj.hash

proc getProof*(blockObj: Block): string =
    return blockObj.proof

proc getLyra*(blockObj: Block): string =
    return blockObj.lyra
