#Lattice Test.

discard """
On Lattice creation:
    Load `lattice_accounts`.
    For each, load the Account.
    Scan the blockchain for all Verification tips from the last 6 Blocks.
    Deduplicate the list, and grab every Verifier's archived tip from `merit_VERIFIER_epoch`.
    Load every Verification from their archived tip to their height.

On Account creation:
    If the Account doesn't exist, add them to `accountsStr` and save it.
    Load `lattice_SENDER` and `lattice_SENDER_confirmed`, which is the height and the nonce of the highest verified Entry, where all previous Entries are also Verified.
    For each Entry between confirmed and height, load it into the cache.
    If it doesn't exist, save 0, 0, 0 to `lattice_SENDER`, `lattice_SENDER_confirmed`, and `lattice_SENDER_balance`.

On Entry addition:
    Save the Entry to `lattice_HASH`.
    For every unconfirmed Entry at that index, save their hashes to `lattice_SENDER_NONCE`.
    Save the Account height to `lattice_SENDER`.

On verification:
    Save the confirmed Entry's hash to `lattice_SENDER_NONCE`.
    Update the Account's confirmed value, and save it to `lattice_SENDER_confirmed`.
    If the balance was changed, save the Account balance to `lattice_SENDER_balance`.

We cache every Entry from the Account's earliest unconfirmed Entry to their tip.
We save every Entry without their verified field.
"""

echo "The Database/Lattice/Lattice Test is empty."
