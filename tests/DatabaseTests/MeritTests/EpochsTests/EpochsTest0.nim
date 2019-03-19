#Epochs Test 0. Verifies that No Verifications = No Rewards.

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Database Function Box.
import ../../../../src/objects/GlobalFunctionBoxObj

#Epoch Test Common lib.
import EpochsTestCommon

var
    #Database Function Box.
    functions: DatabaseFunctionBox = newTestDatabase()
    #Epochs.
    epochs: Epochs = newEpochs(functions)
    #Rewards.
    rewards: Rewards = epochs.shift(
        nil,
        @[]
    ).calculate(nil)

assert(rewards.len == 0)

echo "Finished the Database/Merit/Epochs Test #0."
