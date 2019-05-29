#Consensus DB Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#MeritHolderRecord object.
import ../../../../src/Database/common/objects/MeritHolderRecordObj

#Consensus lib.
import ../../../../src/Database/Consensus/Consensus

#Serialize Verification lib.
import ../../../../src/Network/Serialize/Consensus/SerializeVerification

#Test Database lib.
import ../../TestDatabase

#Compare Consensus lib.
import ../CompareConsensus

#Random standard lib.
import random

#Seed random.
randomize(getTime())

discard """
On Consensus creation:
    Load `consensus_holders`.
    For each, add the MeritHolder.

On MeritHolder creation:
    If the MeritHolder doesn't exist, add them to `holdersStr` and save it.
    Load `consensus_KEY`, which is the quantity archived in string format (not binary).
    For each archived Verification, load `consensus_KEY_NONCE`, which is the hash, and regenerate the Merkle.
    If it doesn't exist, save "-1" to `consensus_KEY`.

On Verification addition:
    Save the verified hash to `consensus_KEY_NONCE`.

On archive:
    Store the archived tip to `consensus_KEY` as a string.

We cache unarchived Elements.
We save unarchived Elements without their signatures.
We don't load unarchived Elements.
"""

var
    #Database.
    db: DatabaseFunctionBox = newTestDatabase()
    #Consensus.
    consensus: Consensus = newConsensus(db)

    #MeritHolders.
    holders: seq[MinerWallet]
    #SignedVerification we just created.
    verif: SignedVerification
    #Tips we're archiving.
    archiving: seq[MeritHolderRecord]

#Tests the Consensus against the reloaded Consensus.
proc test() =
    #Reload the Consensus.
    var reloaded: Consensus = newConsensus(db)

    #Compare the Consensus DAGs.
    compare(consensus, reloaded)

#Iterate over 20 'rounds'.
for _ in 0 ..< 20:
    #Create a random amount of MeritHolders.
    for _ in 0 ..<  rand(2) + 1:
        holders.add(newMinerWallet())

    #Create Elements.
    for e in 0 ..< rand(10):
        var
            #Grab a random MeritHolder.
            i: int = rand(holders.len - 1)
            holder: MinerWallet = holders[i]
            #Hash used in a SignedVerification.
            hash: Hash[384]
        #Randomize the hash.
        for b in 0 .. hash.data.len:
            hash.data[b] = uint8(rand(255))
        #Create the Verification.
        verif = newSignedVerificationObj(hash)
        #Sign it.
        holder.sign(verif, consensus[holder.publicKey].height)

        #Add it as a SignedVerification.
        if rand(1) == 0:
            consensus.add(verif)
        #Add it as a Verification.
        else:
            consensus.add(cast[Verification](verif))

    #Clear archiving and recalculate it.
    archiving = @[]
    for h in 0 ..< holders.len:
        if consensus[holders[h].publicKey].height - 1 == consensus[holders[h].publicKey].archived:
            continue

        archiving.add(
            newMeritHolderRecord(
                holders[h].publicKey,
                consensus[holders[h].publicKey].height - 1,
                consensus[holders[h].publicKey].merkle.hash
            )
        )
    #Archive the records.
    consensus.archive(archiving)

    #Test the Consensus.
    test()

echo "Finished the Database/Consensus/Consensus/DB Test."
