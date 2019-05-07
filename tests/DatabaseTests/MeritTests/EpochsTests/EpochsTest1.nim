discard """
Epochs Test 1. Verifies that 1 Verification = 1000.
"""

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#Merkle lib.
import ../../../../src/Database/common/Merkle

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#VerifierRecord object.
import ../../../../src/Database/common/objects/VerifierRecordObj

#Verifications lib.
import ../../../../src/Database/Verifications/Verifications

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Merit Testing functions.
import ../TestMerit

#String utils standard lib.
import strutils

var
    #Database Function Box.
    functions: DatabaseFunctionBox = newTestDatabase()
    #Verifications.
    verifications: Verifications = newVerifications(functions)
    #Blockchain.
    blockchain: Blockchain = newBlockchain(functions, "EPOCH_TEST_1", 1, "".pad(48).toHash(384))
    #State.
    state: State = newState(functions, 100)
    #Epochs.
    epochs: Epochs = newEpochs(functions, verifications, blockchain)

    #Hash.
    hash: Hash[384] = "aa".repeat(48).toHash(384)
    #MinerWallet.
    miner: MinerWallet = newMinerWallet()
    #MemoryVerification object.
    verif: MemoryVerification
    #VerifierRecords.
    verifs: seq[VerifierRecord] = @[]
    #Rewards.
    rewards: Rewards

#Give Key 0 Merit.
state.processBlock(
    blockchain,
    newTestBlock(
        miners = newMinersObj(@[
            newMinerObj(
                miner.publicKey,
                100
            )
        ])
    )
)

#Add a Verification.
verif = newMemoryVerificationObj(hash)
miner.sign(verif, 0)
#Add it the Verifications.
verifications.add(verif)
#Add a VerifierRecord.
verifs.add(newVerifierRecord(
    miner.publicKey,
    0,
    newMerkle(hash).hash
))

#Shift on the Verifications.
rewards = epochs.shift(verifications, verifs).calculate(state)
assert(rewards.len == 0)

#Shift 4 over.
for _ in 0 ..< 4:
    rewards = epochs.shift(verifications, @[]).calculate(state)
    assert(rewards.len == 0)

#Next shift should result in a Rewards of Key 0, 1000.
rewards = epochs.shift(verifications, @[]).calculate(state)
assert(rewards.len == 1)
assert(rewards[0].key == miner.publicKey.toString())
assert(rewards[0].score == 1000)

echo "Finished the Database/Merit/Epochs Test #1."
