#Epochs Test 2. Verifies that:
# - 2 Verifications
# - For the same Entry
# - A block apart
# Result in 500/500 when the Entry first appeared.

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
    keys: array[2, BLSPrivateKey] = [
        newBLSPrivateKeyFromSeed("0"),
        newBLSPrivateKeyFromSeed("1")
    ]
    #Hashes.
    hash: Hash[512] = "aa".repeat(64).toHash(512)
    #Verifications object.
    verifications: Verifications = newVerificationsObj()
    #Temporary Verification object.
    verif: MemoryVerification
    #Rewards.
    rewards: Rewards

#Give both Keys Merit.
state.processBlock(
    blockchain,
    blankBlock(@[
        newMinerObj(
            keys[0].getPublicKey(),
            50
        ),

        newMinerObj(
            keys[1].getPublicKey(),
            50
        )
    ])
)

#Add a Key 0 Verification.
verif = newMemoryVerificationObj(hash)
verif.verifier = keys[0].getPublicKey()
verifications.verifications.add(verif)

#Shift on the Verifications.
rewards = epochs.shift(verifications).calculate(state)
assert(rewards.len == 0)

#Clear verifications.
verifications = newVerificationsObj()

#Add a Key 1 Verification.
verif = newMemoryVerificationObj(hash)
verif.verifier = keys[1].getPublicKey()
verifications.verifications.add(verif)

#Shift on the Verifications.
rewards = epochs.shift(verifications).calculate(state)
assert(rewards.len == 0)

#Shift 4 over.
for _ in 0 ..< 4:
    rewards = epochs.shift(newVerificationsObj()).calculate(state)
    assert(rewards.len == 0)

#Next shift should result in a Rewards of Key 0, 500 and Key 1, 500.
rewards = epochs.shift(newVerificationsObj()).calculate(state)
#Veirfy the length.
assert(rewards.len == 2)
#Verify each Key in the Rewards was one of two Keys.
assert(
    (rewards[0].key == keys[0].getPublicKey().toString()) or
    (rewards[0].key == keys[1].getPublicKey().toString())
)
assert(
    (rewards[1].key == keys[0].getPublicKey().toString()) or
    (rewards[1].key == keys[1].getPublicKey().toString())
)
#Verify they key's weren't the same.
assert(rewards[0].key != rewards[1].key)
#Verify the scores.
assert(rewards[0].score == 500)
assert(rewards[1].score == 500)

echo "Finished the Database/Merit/Epochs Test 2."
