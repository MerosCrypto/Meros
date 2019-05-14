#Consensus Test.

#Errors lib.
import ../../../src/lib/Errors

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#MeritHolderRecord object.
import ../../../src/Database/common/objects/MeritHolderRecordObj

#Consensus lib.
import ../../../src/Database/Consensus/Consensus

#Serialize lib.
import ../../../src/Network/Serialize/Consensus/SerializeVerification

#Test Database lib.
import ../TestDatabase

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

#Tests the DB's list of holders, tips, and a reloaded copy of the Consensus against the real one.
proc test(archived: seq[MeritHolderRecord], holdersLen: int) =
    #Test the `consensus_holders`.
    var holdersStr: string
    for e in 0 ..< holdersLen:
        holdersStr &= holders[e].publicKey.toString()
    assert(db.get("consensus_holders") == holdersStr)

    #Test the archived tips.
    for tip in archived:
        #Make sure the original Consensus has the same tip.
        assert(consensus[tip.key].archived == int(tip.nonce))
        #Make sure the DB has the same tip.
        assert(db.get("consensus_" & tip.key.toString()) == $tip.nonce)

    #Reload the database.
    var reloaded: Consensus = newConsensus(db)

    #Test each holder.
    for h in holders:
        #Grab each MeritHolder.
        var
            originalMeritHolder: MeritHolder = consensus[h.publicKey]
            reloadedMeritHolder: MeritHolder = reloaded[h.publicKey]

        #Test both have the same fields.
        assert(originalMeritHolder.key == reloadedMeritHolder.key)
        assert(originalMeritHolder.archived == reloadedMeritHolder.archived)

        #Test the Consensus.
        for verif in 0 .. originalMeritHolder.archived:
            assert(originalMeritHolder[verif].holder == reloadedMeritHolder[verif].holder)
            assert(originalMeritHolder[verif].nonce == reloadedMeritHolder[verif].nonce)
            assert(originalMeritHolder[verif].hash == reloadedMeritHolder[verif].hash)

        #Test the Merkle.
        if originalMeritHolder.archived == -1:
            assert(reloadedMeritHolder.merkle.hash.toString() == "".pad(48))

#Create 5 MeritHolders.
for i in 0 ..< 5:
    holders.add(newMinerWallet())

#Create 1 Element for the first MeritHolder.
verif = newSignedVerificationObj(char(0).pad(48).toHash(384))
holders[0].sign(verif, 0)
consensus.add(verif)
assert(db.get("consensus_" & holders[0].publicKey.toString() & "_" & 0.toBinary()) == verif.hash.toString())

#Create 3 Elements for the second MeritHolder.
for i in 0 ..< 3:
    verif = newSignedVerificationObj(char(i).pad(48).toHash(384))
    holders[1].sign(verif, uint(i))
    consensus.add(verif)
    assert(db.get("consensus_" & holders[1].publicKey.toString() & "_" & i.toBinary()) == verif.hash.toString())

#Create 5 Elements for the third MeritHolder.
for i in 0 ..< 5:
    verif = newSignedVerificationObj(char(i).pad(48).toHash(384))
    holders[2].sign(verif, uint(i))
    consensus.add(verif)
    assert(db.get("consensus_" & holders[2].publicKey.toString() & "_" & i.toBinary()) == verif.hash.toString())

#Archive all of these (the Merkle is blank since we check that in the Merit systems, which are out of scope for this test).
archiving = @[
    newMeritHolderRecord(
        holders[0].publicKey,
        0,
        "".pad(48).toHash(384)
    ),
    newMeritHolderRecord(
        holders[1].publicKey,
        2,
        "".pad(48).toHash(384)
    ),
    newMeritHolderRecord(
        holders[2].publicKey,
        4,
        "".pad(48).toHash(384)
    )
]
consensus.archive(archiving)

#Test the Consensus.
test(archiving, 3)

#Add more Elements to each person.
for i in 1 ..< 8:
    verif = newSignedVerificationObj(char(i).pad(48).toHash(384))
    holders[0].sign(verif, uint(i))
    consensus.add(verif)
    assert(db.get("consensus_" & holders[0].publicKey.toString() & "_" & i.toBinary()) == verif.hash.toString())

for i in 3 ..< 7:
    verif = newSignedVerificationObj(char(i).pad(48).toHash(384))
    holders[1].sign(verif, uint(i))
    consensus.add(verif)
    assert(db.get("consensus_" & holders[1].publicKey.toString() & "_" & i.toBinary()) == verif.hash.toString())

for i in 5 ..< 10:
    verif = newSignedVerificationObj(char(i).pad(48).toHash(384))
    holders[2].sign(verif, uint(i))
    consensus.add(verif)
    assert(db.get("consensus_" & holders[2].publicKey.toString() & "_" & i.toBinary()) == verif.hash.toString())

#Add a new MeritHolder.
verif = newSignedVerificationObj(char(0).pad(48).toHash(384))
holders[3].sign(verif, 0)
consensus.add(verif)
assert(db.get("consensus_" & holders[3].publicKey.toString() & "_" & 0.toBinary()) == verif.hash.toString())

#Add a blank MeritHolder.
discard consensus[holders[4].publicKey]

#Archive all of these except the second MeritHolder and the blank holder.
archiving = @[
    newMeritHolderRecord(
        holders[0].publicKey,
        7,
        "".pad(48).toHash(384)
    ),
    newMeritHolderRecord(
        holders[2].publicKey,
        9,
        "".pad(48).toHash(384)
    ),
    newMeritHolderRecord(
        holders[3].publicKey,
        0,
        "".pad(48).toHash(384)
    )
]
consensus.archive(archiving)

#Test the Consensus.
test(archiving, 5)

#Create a Verification for the previously blank MeritHolder.
verif = newSignedVerificationObj(char(0).pad(48).toHash(384))
holders[4].sign(verif, 0)
consensus.add(verif)
assert(db.get("consensus_" & holders[4].publicKey.toString() & "_" & 0.toBinary()) == verif.hash.toString())

#Archive the second holder and the blank holder.
archiving = @[
    newMeritHolderRecord(
        holders[1].publicKey,
        6,
        "".pad(48).toHash(384)
    ),
    newMeritHolderRecord(
        holders[4].publicKey,
        0,
        "".pad(48).toHash(384)
    )
]
consensus.archive(archiving)

#Test the Consensus.
test(archiving, 5)

echo "Finished the Database/Consensus/Consensus Test."
