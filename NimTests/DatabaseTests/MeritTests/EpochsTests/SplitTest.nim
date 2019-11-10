#Epochs Split Test. Verifies that 2 Verifications, a block apart, result in 500/500 when the Transaction appeared.

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
        blockchain: Blockchain = newBlockchain(db, "EPOCH_SPLIT_TEST", 1, "".pad(48).toHash(384))
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
            newMinerWallet()
        ]
        #SignedVerification.
        verif: SignedVerification
        #VerificationPacket.
        packet: SignedVerificationPacket
        #Rewards.
        rewards: seq[Reward]

    for m in 0 ..< miners.len:
        #Give the miner Merit.
        blockchain.processBlock(newBlankBlock(miner = miners[m]))
        state.processBlock(blockchain)

        #Set the miner's nickname.
        miners[m].nick = uint16(m)

        #Create the Verification.
        verif = newSignedVerificationObj(hash)
        miners[m].sign(verif)

        #Add it to the packet.
        packet = newSignedVerificationPacketObj(hash)
        packet.add(verif)

        #Shift on the packet.
        rewards = epochs.shift(newBlankBlock(
            packets = cast[seq[VerificationPacket]](@[packet])
        )).calculate(state)
        assert(rewards.len == 0)

    #Shift 3 over.
    for e in 0 ..< 3:
        if e < 2:
            newBlock = newBlankBlock(
                nick = uint16(e),
                miner = miners[e]
            )
        else:
            newBlock = newBlankBlock()
        blockchain.processBlock(newBlock)
        state.processBlock(blockchain)

        rewards = epochs.shift(newBlock).calculate(state)
        assert(rewards.len == 0)

    #Next shift should result in a Rewards of 0: 500, 1: 500, and 2: 500.
    rewards = epochs.shift(newBlankBlock()).calculate(state)

    #Veirfy the length.
    assert(rewards.len == 2)

    #Verify each nick is accurate and assigned to the right key.
    for r1 in 0 ..< rewards.len:
        assert(rewards[r1].nick == uint16(r1))
        assert(state.holders[r1] == miners[r1].publicKey)

    #Verify the scores.
    assert(rewards[0].score == 500)
    assert(rewards[1].score == 500)

    echo "Finished the Database/Merit/Epochs Split Test."
