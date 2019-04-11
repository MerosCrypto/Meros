discard """
Epochs Test 2. Verifies that:
 - 2 Verifications
 - For the same Entry
 - A block apart
Result in 500/500 when the Entry first appeared.
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

#BN lib.
import BN

var
    #Database Function Box.
    functions: DatabaseFunctionBox = newTestDatabase()
    #Verifications.
    verifications: Verifications = newVerifications(functions)
    #Blockchain.
    blockchain: Blockchain = newBlockchain(functions, "EPOCH_TEST_2", 1, newBN(0))
    #State.
    state: State = newState(functions, 100)
    #Epochs.
    epochs: Epochs = newEpochs(functions, verifications, blockchain)

    #Hash.
    hash: Hash[384] = "".pad(48, char(128)).toHash(384)
    #MinerWallets.
    miners: seq[MinerWallet] = @[
        newMinerWallet(),
        newMinerWallet()
    ]
    #MemoryVerification object.
    verif: MemoryVerification
    #VerifierRecords.
    verifs: seq[VerifierRecord] = @[]
    #Rewards.
    rewards: Rewards

#Give both Keys Merit.
state.processBlock(
    blockchain,
    newTestBlock(
        miners = newMinersObj(@[
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
)

#Add a Key 0 Verification.
verif = newMemoryVerificationObj(hash)
miners[0].sign(verif, 0)
#Add it the Verifications.
verifications.add(verif)
#Add a VerifierRecord.
verifs.add(newVerifierRecord(
    miners[0].publicKey,
    0,
    newMerkle(hash).hash
))

#Shift on the Verifications.
rewards = epochs.shift(verifications, verifs).calculate(state)
assert(rewards.len == 0)

#Clear the VerifierRecords.
verifs = @[]

#Add a Key 1 Verification.
verif = newMemoryVerificationObj(hash)
miners[1].sign(verif, 0)
#Add it the Verifications.
verifications.add(verif)
#Add a VerifierRecord.
verifs.add(newVerifierRecord(
    miners[1].publicKey,
    0,
    newMerkle(hash).hash
))

#Shift on the Verifications.
rewards = epochs.shift(verifications, verifs).calculate(state)
assert(rewards.len == 0)

#Shift 3 over.
for _ in 0 ..< 3:
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
