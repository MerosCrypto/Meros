#Epochs Empty Test. Verifies that No Verifications = No Rewards.

#Test lib.
import unittest2

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Merit Testing functions.
import ../TestMerit

suite "Empty":

    test "Verify.":
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
            epochs: Epochs = newEpochs(blockchain)
            #Rewards.
            rewards: seq[Reward] = epochs.shift(newBlankBlock()).calculate(state)

        assert(rewards.len == 0)
