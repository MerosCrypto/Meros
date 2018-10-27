#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Base lib.
import ../../lib/Base

#BLS lib.
import ../../lib/BLS

#Miners object, Verification/Block/Blockchain/State/Epochs/MinerWallet libs.
import objects/MinersObj
import Verifications
import Block
import Blockchain
import State
import Epochs
import Miner/MinerWallet

export MinersObj
export Verifications
export Block
export Blockchain
export State
export Epochs
export MinerWallet

#Finals lib.
import finals

#Merit master object for a blockchain and state.
type Merit* = ref object of RootObj
    blockchain*: Blockchain
    state*: State
    epochs: Epochs
    miner*: MinerWallet

#Constructor.
proc newMerit*(
    genesis: string,
    blockTime: uint,
    startDifficulty: string,
    live: uint
): Merit {.raises: [ValueError, ArgonError].} =
    Merit(
        blockchain: newBlockchain(genesis, blockTime, startDifficulty.toBN(16)),
        state: newState(live),
        epochs: newEpochs()
    )

#Set the MinerWallet.
proc setMinerWallet*(merit: Merit, keyArg: string) {.raises: [BLSError].} =
    merit.miner = newMinerWallet(newBLSPrivateKeyFromBytes(keyArg))

#Create a Verification.
proc verify*(merit: Merit, hash: Hash[512]): MemoryVerification =
    result = newMemoryVerification(hash)
    result.verifier = merit.miner.publicKey
    result.signature = merit.miner.sign(hash.toString())

#Add a block.
proc processBlock*(
    merit: Merit,
    newBlock: Block
): Rewards {.raises: [
    KeyError,
    ValueError,
    BLSError,
    SodiumError,
    FinalAttributeError
].} =
    #Add the block to the Blockchain.
    if not merit.blockchain.processBlock(newBlock):
        #If that fails, throw a ValueError.
        raise newException(ValueError, "Invalid Block.")

    #Have the state process the block.
    merit.state.processBlock(merit.blockchain, newBlock)

    #Have the Epochs process the Block.
    var epoch: Epoch = merit.epochs.shift(newBlock.verifications)
    #Calculate the rewards.
    result = epoch.calculate(merit.state)
