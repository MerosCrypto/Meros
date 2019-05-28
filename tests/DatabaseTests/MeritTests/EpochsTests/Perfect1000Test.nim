#Epochs Perfect 1000 Test. Verifies that 3 Verifications still result in a total of 1000.

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
    blockchain: Blockchain = newBlockchain(functions, "EPOCH_PERFECT_1000_TEST", 1, "".pad(48).toHash(384))
    #State.
    state: State = newState(functions, 100)
    #Epochs.
    epochs: Epochs = newEpochs(functions, consensus, blockchain)

    #Hash.
    hash: Hash[384] = "".pad(48, char(128)).toHash(384)
    #MinerWallets.
    miners: seq[MinerWallet] = @[
        newMinerWallet(),
        newMinerWallet(),
        newMinerWallet()
    ]
    #SignedVerification object.
    verif: SignedVerification
    #MeritHolderRecords.
    verifs: seq[MeritHolderRecord] = @[]
    #Rewards.
    rewards: seq[Reward]

#Give both Keys Merit.
state.processBlock(
    blockchain,
    newBlankBlock(
        miners = newMinersObj(@[
            newMinerObj(
                miners[0].publicKey,
                100
            )
        ])
    )
)
state.processBlock(
    blockchain,
    newBlankBlock(
        miners = newMinersObj(@[
            newMinerObj(
                miners[1].publicKey,
                100
            )
        ])
    )
)
state.processBlock(
    blockchain,
    newBlankBlock(
        miners = newMinersObj(@[
            newMinerObj(
                miners[2].publicKey,
                100
            )
        ])
    )
)


#Add a Key 0 Verification.
verif = newSignedVerificationObj(hash)
miners[0].sign(verif, 0)
#Add it the Consensus.
consensus.add(verif)

#Add a Key 1 Verification.
verif = newSignedVerificationObj(hash)
miners[1].sign(verif, 0)
#Add it the Consensus.
consensus.add(verif)

#Add a Key 2 Verification.
verif = newSignedVerificationObj(hash)
miners[2].sign(verif, 0)
#Add it the Consensus.
consensus.add(verif)

#Add MeritHolderRecords.
verifs.add(newMeritHolderRecord(
    miners[0].publicKey,
    0,
    newMerkle(hash).hash
))
verifs.add(newMeritHolderRecord(
    miners[1].publicKey,
    0,
    newMerkle(hash).hash
))
verifs.add(newMeritHolderRecord(
    miners[2].publicKey,
    0,
    newMerkle(hash).hash
))

#Shift on the Verifications.
rewards = epochs.shift(consensus, verifs).calculate(state)
assert(rewards.len == 0)

#Shift 4 over.
for _ in 0 ..< 4:
    rewards = epochs.shift(consensus, @[]).calculate(state)
    assert(rewards.len == 0)

#Next shift should result in a Rewards of Key 0: 334, Key 1: 333, and Key 2: 333.
rewards = epochs.shift(consensus, @[]).calculate(state)
#Veirfy the length.
assert(rewards.len == 3)
#Verify each Key in the Rewards was one of the three Keys.
assert(
    (rewards[0].key == miners[0].publicKey.toString()) or
    (rewards[0].key == miners[1].publicKey.toString()) or
    (rewards[0].key == miners[2].publicKey.toString())
)
assert(
    (rewards[1].key == miners[0].publicKey.toString()) or
    (rewards[1].key == miners[1].publicKey.toString()) or
    (rewards[1].key == miners[2].publicKey.toString())
)
assert(
    (rewards[2].key == miners[0].publicKey.toString()) or
    (rewards[2].key == miners[1].publicKey.toString()) or
    (rewards[2].key == miners[2].publicKey.toString())
)
#Verify the keys weren't the same.
assert(rewards[0].key != rewards[1].key)
assert(rewards[0].key != rewards[2].key)
assert(rewards[1].key != rewards[2].key)

#Verify the scores.
assert(rewards[0].score == 334)
assert(rewards[1].score == 333)
assert(rewards[2].score == 333)

echo "Finished the Database/Merit/Epochs Perfect 1000 Test."
