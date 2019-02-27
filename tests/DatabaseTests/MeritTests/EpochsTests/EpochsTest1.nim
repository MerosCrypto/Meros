#Epochs Test 1. Verifies that 1 Verification = 1000.

#BN lib.
import BN

#Hash lib.
import ../../../../src/lib/Hash

#Merkle lib.
import ../../../../src/lib/Merkle

#BLS and minerWallet libs.
import ../../../../src/lib/BLS
import ../../../../src/Wallet/MinerWallet

#Verifications lib.
import ../../../../src/Database/Verifications/Verifications

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Database Function Box.
import ../../../../src/objects/GlobalFunctionBoxObj

#Epoch Test Common lib.
import EpochsTestCommon

#String utils standard lib.
import strutils

var
    #Database Function Box.
    functions: DatabaseFunctionBox = newTestDatabase()
    #Verifications.
    verifications: Verifications = newVerifications(functions)
    #Blockchain.
    blockchain: Blockchain = newBlockchain("epoch test", 1, newBN(0))
    #State.
    state: State = newState(100)
    #Epochs.
    epochs: Epochs = newEpochs()
    #VerifierIndexes.
    verifs: seq[VerifierIndex] = @[]

    #MinerWallet.
    miner: MinerWallet = newMinerWallet()
    #Hash.
    hash: Hash[512] = "aa".repeat(64).toHash(512)
    #MemoryVerification object.
    verif: MemoryVerification
    #Rewards.
    rewards: Rewards

#Give Key 0 Merit.
state.processBlock(
    blockchain,
    blankBlock(@[
        newMinerObj(
            miner.publicKey,
            100
        )
    ])
)

#Add a Verification.
verif = newMemoryVerificationObj(hash)
miner.sign(verif, 0)
#Add it the Verifications.
verifications.add(verif)
#Add a VerifierIndex.
verifs.add(newVerifierIndex(
    miner.publicKey.toString(),
    0,
    newMerkle(hash.toString()).hash
))

#Shift on the Verifications.
rewards = epochs.shift(verifications, verifs).calculate(state)
assert(rewards.len == 0)

#Shift 5 over.
for _ in 0 ..< 5:
    rewards = epochs.shift(verifications, @[]).calculate(state)
    assert(rewards.len == 0)

#Next shift should result in a Rewards of Key 0, 1000.
rewards = epochs.shift(verifications, @[]).calculate(state)
assert(rewards.len == 1)
assert(rewards[0].key == miner.publicKey.toString())
assert(rewards[0].score == 1000)

echo "Finished the Database/Merit/Epochs Test #1."
