discard """
Epochs Test 2. Verifies that:
 - 2 Verifications
 - For the same Entry
 - A block apart
Result in 500/500 when the Entry first appeared.
"""

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
    blockchain: Blockchain = newBlockchain("epoch test", 1, newBN(0), nil)
    #State.
    state: State = newState(100)
    #Epochs.
    epochs: Epochs = newEpochs()
    #VerifierIndexes.
    verifs: seq[VerifierIndex] = @[]

    #MinerWallet.
    miners: seq[MinerWallet] = @[
        newMinerWallet(),
        newMinerWallet()
    ]
    #Hash.
    hash: Hash[512] = "aa".repeat(64).toHash(512)
    #MemoryVerification object.
    verif: MemoryVerification
    #Rewards.
    rewards: Rewards

#Give both Keys Merit.
state.processBlock(
    blockchain,
    blankBlock(@[
        newMinerObj(
            miners[0].publicKey,
            50
        ),

        newMinerObj(
            miners[1].publicKey,
            50
        )
    ])
)

#Add a Key 0 Verification.
verif = newMemoryVerificationObj(hash)
miners[0].sign(verif, 0)
#Add it the Verifications.
verifications.add(verif)
#Add a VerifierIndex.
verifs.add(newVerifierIndex(
    miners[0].publicKey.toString(),
    0,
    newMerkle(hash.toString()).hash
))

#Shift on the Verifications.
rewards = epochs.shift(verifications, verifs).calculate(state)
assert(rewards.len == 0)

#Clear the VerifierIndexes.
verifs = @[]

#Add a Key 1 Verification.
verif = newMemoryVerificationObj(hash)
miners[1].sign(verif, 0)
#Add it the Verifications.
verifications.add(verif)
#Add a VerifierIndex.
verifs.add(newVerifierIndex(
    miners[1].publicKey.toString(),
    0,
    newMerkle(hash.toString()).hash
))

#Shift on the Verifications.
rewards = epochs.shift(verifications, verifs).calculate(state)
assert(rewards.len == 0)

#Shift 4 over.
for _ in 0 ..< 4:
    rewards = epochs.shift(verifications, @[]).calculate(state)
    assert(rewards.len == 0)

#Next shift should result in a Rewards of Key 0, 500 and Key 1, 500.
rewards = epochs.shift(verifications, @[]).calculate(state)
#Veirfy the length.
assert(rewards.len == 2)
#Verify each Key in the Rewards was one of two Keys.
assert(
    (rewards[0].key == miners[0].publicKey.toString()) or
    (rewards[0].key == miners[1].publicKey.toString())
)
assert(
    (rewards[1].key == miners[0].publicKey.toString()) or
    (rewards[1].key == miners[1].publicKey.toString())
)
#Verify the keys weren't the same.
assert(rewards[0].key != rewards[1].key)
#Verify the scores.
assert(rewards[0].score == 500)
assert(rewards[1].score == 500)

echo "Finished the Database/Merit/Epochs Test #2."
