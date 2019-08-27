#Epochs Empty Test. Verifies that No Verifications = No Rewards.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#Blockchain lib.
import ../../../../src/Database/Merit/Blockchain

#State lib.
import ../../../../src/Database/Merit/State

#Epochs lib.
import ../../../../src/Database/Merit/Epochs

#Merit Testing functions.
import ../TestMerit

proc test*() =
    var
        #Database Function Box.
        functions: DB = newTestDatabase()
        #Blockchain.
        blockchain: Blockchain = newBlockchain(functions, "EPOCH_EMPTY_TEST", 1, "".pad(48).toHash(384))
        #State.
        state: State = newState(functions, 1, blockchain.height)
        #Epochs.
        epochs: Epochs = newEpochs(functions, nil, blockchain)
        #Rewards.
        rewards: seq[Reward] = epochs.shift(
            nil,
            @[],
            @[]
        ).calculate(state)

    assert(rewards.len == 0)

    echo "Finished the Database/Merit/Epochs Empty Test."
