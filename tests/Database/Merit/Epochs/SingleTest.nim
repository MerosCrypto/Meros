#Epochs Single Test. Verifies that 1 Verification = 1000.

#Test lib.
import unittest2

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

suite "Single":

    test "Verify.":
        var
            #Database Function Box.
            db: DB = newTestDatabase()
            #Blockchain.
            blockchain: Blockchain = newBlockchain(db, "EPOCH_SINGLE_TEST", 1, "".pad(48).toHash(384))
            #State.
            state: State = newState(db, 100, blockchain.height)
            #Epochs.
            epochs: Epochs = newEpochs(blockchain)
            #New Block.
            newBlock: Block

            #Hash.
            hash: Hash[384] = "".pad(48, char(128)).toHash(384)
            #MinerWallets.
            miner: MinerWallet = newMinerWallet()
            #SignedVerification.
            verif: SignedVerification
            #VerificationPacket.
            packet: SignedVerificationPacket = newSignedVerificationPacketObj(hash)
            #Rewards.
            rewards: seq[Reward]

        #Give the miner Merit.
        blockchain.processBlock(newBlankBlock(miner = miner))
        discard state.processBlock(blockchain)

        #Set the miner's nickname.
        miner.nick = uint16(0)

        #Create the Verification.
        verif = newSignedVerificationObj(hash)
        miner.sign(verif)

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
                nick = uint16(0),
                miner = miner
            )
            blockchain.processBlock(newBlock)
            discard state.processBlock(blockchain)

            rewards = epochs.shift(newBlock).calculate(state)
            assert(rewards.len == 0)

        #Next shift should result in a Rewards of 0: 1000.
        rewards = epochs.shift(newBlankBlock()).calculate(state)
        assert(rewards.len == 1)
        assert(rewards[0].nick == 0)
        assert(state.holders[0] == miner.publicKey)
        assert(rewards[0].score == 1000)
