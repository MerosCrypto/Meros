#Epochs Test 0. Verifies that No Verifications = No Rewards.

#Merit lib.
import ../../../../src/Database/Merit/Merit

var
    epochs: Epochs = newEpochs()
    rewards: Rewards = epochs.shift(
        nil,
        @[]
    ).calculate(nil)

assert(rewards.len == 0)

echo "Finished the Database/Merit/Epochs Test #0."
