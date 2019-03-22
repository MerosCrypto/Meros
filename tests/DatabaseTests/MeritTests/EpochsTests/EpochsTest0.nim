discard """
Epochs Test 0. Verifies that No Verifications = No Rewards.
"""

#Epochs lib.
import ../../../../src/Database/Merit/Epochs

#Merit Testing functions.
import ../TestMerit

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
