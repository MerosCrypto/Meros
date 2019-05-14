discard """
Epochs Test 2. Verifies that:
    - 2 Consensus
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

#MeritHolderRecord object.
import ../../../../src/Database/common/objects/MeritHolderRecordObj

#Consensus lib.
import ../../../../src/Database/Consensus/Consensus

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Merit Testing functions.
import ../TestMerit

var
    #Database Function Box.
    functions: DatabaseFunctionBox = newTestDatabase()
    #Consensus.
    consensus: Consensus = newConsensus(functions)
    #Blockchain.
    blockchain: Blockchain = newBlockchain(functions, "EPOCH_TEST_2", 1, "".pad(48).toHash(384))
    #State.
    state: State = newState(functions, 100)
    #Epochs.
    epochs: Epochs = newEpochs(functions, consensus, blockchain)

    #Hash.
    hash: Hash[384] = "".pad(48, char(128)).toHash(384)
    #MinerWallets.
    miners: seq[MinerWallet] = @[
        newMinerWallet(),
        newMinerWallet()
    ]
    #SignedVerification object.
    verif: SignedVerification
    #MeritHolderRecords.
    verifs: seq[MeritHolderRecord] = @[]
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
verif = newSignedVerificationObj(hash)
miners[0].sign(verif, 0)
#Add it the Consensus.
consensus.add(verif)
#Add a MeritHolderRecord.
verifs.add(newMeritHolderRecord(
    miners[0].publicKey,
    0,
    newMerkle(hash).hash
))

#Shift on the Verifications.
rewards = epochs.shift(consensus, verifs).calculate(state)
assert(rewards.len == 0)

#Clear the MeritHolderRecords.
verifs = @[]

#Add a Key 1 Verification.
verif = newSignedVerificationObj(hash)
miners[1].sign(verif, 0)
#Add it the Consensus.
consensus.add(verif)
#Add a MeritHolderRecord.
verifs.add(newMeritHolderRecord(
    miners[1].publicKey,
    0,
    newMerkle(hash).hash
))

#Shift on the Verifications.
rewards = epochs.shift(consensus, verifs).calculate(state)
assert(rewards.len == 0)

#Shift 3 over.
for _ in 0 ..< 3:
    rewards = epochs.shift(consensus, @[]).calculate(state)
    assert(rewards.len == 0)

#Next shift should result in a Rewards of Key 0, 500 and Key 1, 500.
rewards = epochs.shift(consensus, @[]).calculate(state)
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
