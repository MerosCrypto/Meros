#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Base lib.
import ../../lib/Base

#BLS lib.
import ../../lib/BLS

#Miners object, Verification/Block/Blockchain/State, and MinerWallet libs.
import objects/MinersObj
import Verifications
import Block
import Blockchain
import State
import Miner/MinerWallet

export MinersObj
export Verifications
export Block
export Blockchain
export State
export MinerWallet

#Merit master object for a blockchain and state.
type Merit* = ref object of RootObj
    blockchain*: Blockchain
    state*: State
    miner*: MinerWallet

#Constructor.
proc newMerit*(
    genesis: string,
    blockTime: uint,
    startDifficulty: string,
    live: uint
): Merit {.raises: [ValueError, ArgonError].} =
    result = Merit(
        blockchain: newBlockchain(genesis, blockTime, startDifficulty.toBN(16)),
        state: newState(live)
    )

#Set the MinerWallet.
proc setMinerWallet*(merit: Merit, keyArg: string) {.raises: [BLSError].} =
    var key: BLSPrivateKey
    try:
        key = newBLSPrivateKeyFromBytes(keyArg)
    except:
        raise newException(BLSError, "Invalid BLS Private Key.")

    merit.miner = newMinerWallet(key)

#Create a Verification.
proc verify*(merit: Merit, hash: Hash[512]): MemoryVerification =
    result = newMemoryVerification(hash)
    result.verifier = merit.miner.publicKey
    result.signature = merit.miner.sign(hash.toString())

#Add a block.
proc processBlock*(
    merit: Merit,
    newBlock: Block
): bool {.raises: [
    KeyError,
    ValueError,
    BLSError,
    SodiumError
].} =
    result = true

    #Add the block to the Blockchain.
    if not merit.blockchain.processBlock(newBlock):
        #If that fails, return false.
        return false

    #Have the state process the block.
    merit.state.processBlock(merit.blockchain, newBlock)
