#Epochs Test 0. Verifies that no Verifications = No Rewards.

discard """
#Merit lib.
import ../../../../src/Database/Merit/Merit

var
    epochs: Epochs = newEpochs()
    rewards: Rewards = epochs.shift(
        newVerificationsObj()
    ).calculate(nil)

assert(rewards.len == 0)

echo "Finished the Database/Merit/Epochs Test #0."
"""
