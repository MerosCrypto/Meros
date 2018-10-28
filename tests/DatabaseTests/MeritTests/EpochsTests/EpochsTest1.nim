#Epochs Test 1. Verifies that 1 Verification = 1000.

#BN lib.
import BN

#Hash lib.
import ../../../../src/lib/Hash

#BLS lib.
import ../../../../src/lib/BLS

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Epoch Test Common lib.
import EpochsTestCommon

#String utils standard lib.
import strutils

var
    #Epochs.
    epochs: Epochs = newEpochs()
    #Blockchain.
    blockchain: Blockchain = newBlockchain("epoch test", 1, newBN(0))
    #State.
    state: State = newState(100)
    #BLS Keys.
    key: BLSPrivateKey = newBLSPrivateKeyFromSeed("0")
    #Hash.
    hash: Hash[512] = "aa".repeat(64).toHash(512)
    #Verifications object.
    verifications: Verifications = newVerificationsObj()
    #Temporary Verification object.
    verif: MemoryVerification
    #Rewards.
    rewards: Rewards

#Give Key 0 Merit.
state.processBlock(
    blockchain,
    blankBlock(@[
        newMinerObj(
            key.getPublicKey(),
            100
        )
    ])
)

#Add a Hash 0/Key 0 Verification.
verif = newMemoryVerificationObj(hash)
verif.verifier = key.getPublicKey()
verifications.verifications.add(verif)

#Shift on the Verifications.
rewards = epochs.shift(verifications).calculate(state)
assert(rewards.len == 0)

#Shift 5 over.
for _ in 0 ..< 5:
    rewards = epochs.shift(newVerificationsObj()).calculate(state)
    assert(rewards.len == 0)

#Next shift should result in a Rewards of Key 0, 1000.
rewards = epochs.shift(newVerificationsObj()).calculate(state)
assert(rewards.len == 1)
assert(rewards[0].key == key.getPublicKey().toString())
assert(rewards[0].score == 1000)

echo "Finished the Database/Merit/Epochs test 1."
