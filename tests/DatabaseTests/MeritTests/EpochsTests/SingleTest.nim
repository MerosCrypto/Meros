discard """
Epochs Single Test. Verifies that 1 Verification = 1000.
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

#String utils standard lib.
import strutils

var
    #Database Function Box.
    functions: DatabaseFunctionBox = newTestDatabase()
    #Consensus.
    consensus: Consensus = newConsensus(functions)
    #Blockchain.
    blockchain: Blockchain = newBlockchain(functions, "EPOCH_SINGLE_TEST", 1, "".pad(48).toHash(384))
    #State.
    state: State = newState(functions, 100)
    #Epochs.
    epochs: Epochs = newEpochs(functions, consensus, blockchain)

    #Hash.
    hash: Hash[384] = "aa".repeat(48).toHash(384)
    #MinerWallet.
    miner: MinerWallet = newMinerWallet()
    #SignedVerification object.
    verif: SignedVerification
    #MeritHolderRecords.
    verifs: seq[MeritHolderRecord] = @[]
    #Rewards.
    rewards: seq[Reward]

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
verif = newSignedVerificationObj(hash)
miner.sign(verif, 0)
#Add it the Consensus.
consensus.add(verif)
#Add a MeritHolderRecord.
verifs.add(newMeritHolderRecord(
    miner.publicKey,
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

#Next shift should result in a Rewards of Key 0, 1000.
rewards = epochs.shift(consensus, @[]).calculate(state)
assert(rewards.len == 1)
assert(rewards[0].key == miner.publicKey.toString())
assert(rewards[0].score == 1000)

echo "Finished the Database/Merit/Epochs Single Test."
