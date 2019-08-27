discard """
Epochs Split Test. Verifies that:
    - 2 Verifications
    - For the same Transaction
    - A block apart
Result in 500/500 when the Transaction first appeared.
"""

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
        blockchain: Blockchain = newBlockchain(functions, "EPOCH_SPLIT_TEST", 1, "".pad(48).toHash(384))
        #State.
        state: State = newState(functions, 100, blockchain.height)
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
        #Rewards.
        rewards: seq[Reward]

    for miner in miners:
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

        #Shift on the record.
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

    #Shift 3 over.
    for _ in 0 ..< 3:
        rewards = epochs.shift(consensus, @[], @[]).calculate(state)
        assert(rewards.len == 0)

    #Next shift should result in a Rewards of key 0, 500 and key 1, 500.
    rewards = epochs.shift(consensus, @[], @[]).calculate(state)

    #Veirfy the length.
    assert(rewards.len == 2)

    #Verify each key is unique and one of our keys.
    for r1 in 0 ..< rewards.len:
        for r2 in 0 ..< rewards.len:
            if r1 == r2:
                continue
            assert(rewards[r1].key != rewards[r2].key)

        for m in 0 ..< miners.len:
            if rewards[r1].key == miners[m].publicKey.toString():
                break

            if m == miners.len - 1:
                assert(false)

    #Verify the scores.
    assert(rewards[0].score == 500)
    assert(rewards[1].score == 500)

    echo "Finished the Database/Merit/Epochs Split Test."
