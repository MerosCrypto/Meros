#Epochs Empty Test. Verifies that No Verifications = No Rewards.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#VerificationPacket lib.
import ../../../../src/Database/Consensus/Elements/VerificationPacket as VerificationPacketFile

#Blockchain lib.
import ../../../../src/Database/Merit/Blockchain

#State lib.
import ../../../../src/Database/Merit/State

#Epochs lib.
import ../../../../src/Database/Merit/Epochs

#Merit Testing functions.
import ../TestMerit

#Tables standard lib.
import tables

proc test*() =
    var
        #Database.
        db: DB = newTestDatabase()
        #Blockchain.
        blockchain: Blockchain = newBlockchain(db, "EPOCH_EMPTY_TEST", 1, "".pad(48).toHash(384))
        #State.
        state: State = newState(
            db,
            5,
            blockchain.height
        )
        #Epochs.
        epochs: Epochs = newEpochs(nil, blockchain)
        #Rewards.
        rewards: seq[Reward] = epochs.shift(
            newBlankBlock(),
            initTable[Hash[384], VerificationPacket]()
        ).calculate(state)

    assert(rewards.len == 0)

    echo "Finished the Database/Merit/Epochs Empty Test."
