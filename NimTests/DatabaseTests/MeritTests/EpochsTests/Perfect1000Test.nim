#Epochs Perfect 1000 Test. Verifies that 3 Verifications still result in a total of 1000.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Verification/VerificationPacket libs.
import ../../../../src/Database/Consensus/Elements/Verification
import ../../../../src/Database/Consensus/Elements/VerificationPacket

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Merit Testing functions.
import ../TestMerit

#Tables standard lib.
import tables

proc test*() =
    var
        #Database Function Box.
        db: DB = newTestDatabase()
        #Blockchain.
        blockchain: Blockchain = newBlockchain(db, "EPOCH_PERFECT_1000_TEST", 1, "".pad(48).toHash(384))
        #State.
        state: State = newState(db, 100, blockchain.height)
        #Epochs.
        epochs: Epochs = newEpochs(blockchain)
        #New Block.
        newBlock: Block

        #Hash.
        hash: Hash[384] = "".pad(48, char(128)).toHash(384)
        #MinerWallets.
        miners: seq[MinerWallet] = @[
            newMinerWallet(),
            newMinerWallet(),
            newMinerWallet()
        ]
        #SignedVerification.
        verif: SignedVerification
        #VerificationPacket.
        packet: SignedVerificationPacket = newSignedVerificationPacketObj(hash)
        #Rewards.
        rewards: seq[Reward]

    for m in 0 ..< miners.len:
        #Give the miner Merit.
        blockchain.processBlock(newBlankBlock(miner = miners[m]))
        state.processBlock(blockchain)

        #Set the miner's nickname.
        miners[m].nick = uint16(m)

        #If the miner isn't the first, give them more Merit.
        #This provides the miners with 1, 2, and 2, respectively.
        #Below, we mine 4 Blocks with a mod 3.
        #That adds 2, 1, and 1, respectively, balancing everything out.
        if m != 0:
            blockchain.processBlock(newBlankBlock(miner = miners[m]))
            state.processBlock(blockchain)

        #Create the Verification.
        verif = newSignedVerificationObj(hash)
        miners[m].sign(verif)

        #Add it to the packet.
        packet.add(verif)

    #Shift on the packet.
    rewards = epochs.shift(newBlankBlock(
        packets = cast[seq[VerificationPacket]](@[packet])
    )).calculate(state)
    assert(rewards.len == 0)

    #Shift 4 over.
    for e in 0 ..< 4:
        newBlock = newBlankBlock(
            nick = uint16(e mod 3),
            miner = miners[e mod 3]
        )
        blockchain.processBlock(newBlock)
        state.processBlock(blockchain)

        rewards = epochs.shift(newBlock).calculate(state)
        assert(rewards.len == 0)

    #Next shift should result in a Rewards of 0: 334, 1: 333, and 2: 333.
    rewards = epochs.shift(newBlankBlock()).calculate(state)

    #Veirfy the length.
    assert(rewards.len == 3)

    #Verify each nick is accurate and assigned to the right key.
    for r1 in 0 ..< rewards.len:
        assert(rewards[r1].nick == uint16(r1))
        assert(state.holders[r1] == miners[r1].publicKey)

    #Verify the scores.
    assert(rewards[0].score == 334)
    assert(rewards[1].score == 333)
    assert(rewards[2].score == 333)

    echo "Finished the Database/Merit/Epochs Perfect 1000 Test."
