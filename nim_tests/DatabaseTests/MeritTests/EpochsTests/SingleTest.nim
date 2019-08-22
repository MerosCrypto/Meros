#Epochs Single Test. Verifies that 1 Verification = 1000.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

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

proc test*() =
    var
        #Database Function Box.
        functions: DB = newTestDatabase()
        #Consensus.
        consensus: Consensus = newConsensus(functions)
        #Blockchain.
        blockchain: Blockchain = newBlockchain(functions, "EPOCH_SINGLE_TEST", 1, "".pad(48).toHash(384))
        #State.
        state: State = newState(functions, 100, blockchain.height)
        #Epochs.
        epochs: Epochs = newEpochs(functions, consensus, blockchain)

        #Hash.
        hash: Hash[384] = "".pad(48, char(128)).toHash(384)
        #MinerWallets.
        miner: MinerWallet = newMinerWallet()
        #SignedVerification object.
        verif: SignedVerification
        #Rewards.
        rewards: seq[Reward]

    #Give the miner Merit.
    state.processBlock(
        blockchain,
        newBlankBlock(
            miners = newMinersObj(@[
                newMinerObj(
                    miner.publicKey,
                    100
                )
            ])
        )
    )

    #Create and add the Verification.
    verif = newSignedVerificationObj(hash)
    miner.sign(verif, 0)
    consensus.add(verif, true)

    #Shift on the records.
    rewards = epochs.shift(
        consensus,
        @[],
        @[
            newMeritHolderRecord(
                miner.publicKey,
                0,
                hash
            )
        ]
    ).calculate(state)
    assert(rewards.len == 0)

    #Shift 4 over.
    for _ in 0 ..< 4:
        rewards = epochs.shift(consensus, @[], @[]).calculate(state)
        assert(rewards.len == 0)

    #Next shift should result in a Rewards of key 0, 1000.
    rewards = epochs.shift(consensus, @[], @[]).calculate(state)
    assert(rewards.len == 1)
    assert(rewards[0].key == miner.publicKey.toString())
    assert(rewards[0].score == 1000)

    echo "Finished the Database/Merit/Epochs Single Test."
