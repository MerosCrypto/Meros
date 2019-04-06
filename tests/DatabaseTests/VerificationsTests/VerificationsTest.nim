#Verifications Test.

#Errors lib.
import ../../../src/lib/Errors

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#Numerical libs.
import BN
import ../../../src/lib/Base

#BLS and MinerWallet libs.
import ../../../src/lib/BLS
import ../../../src/Wallet/MinerWallet

#VerifierIndex object.
import ../../../src/Database/Merit/objects/VerifierIndexObj

#Verifications lib.
import ../../../src/Database/Verifications/Verifications

#Serialize lib.
import ../../../src/Network/Serialize/Verifications/SerializeVerification

#Test Database lib.
import ../TestDatabase

discard """
On Verifications creation:
    Load `verifications_verifiers`.
    For each, add the Verifier.

On Verifier creation:
    If the Verifier doesn't exist, add them to `verifiersStr` and save it.
    Load `verifications_KEY`, which is the quantity archived in string format (not binary).
    For each archived Verification, load `verifications_KEY_NONCE`, which is the hash, and regenerate the Merkle.
    If it doesn't exist, save "-1" to `verifications_KEY`.

On Verification addition:
    Save the verified hash to `verifications_KEY_NONCE`.

On archive:
    Store the archived tip to `verifications_KEY` as a string.

We cache unarchived Verifications.
We save unarchived Verifications without their signatures.
We don't load unarchived Verifications.
"""

var
    #Database.
    db: DatabaseFunctionBox = newTestDatabase()
    #Verifications.
    verifications: Verifications = newVerifications(db)
    #Verifiers.
    verifiers: seq[MinerWallet]

    #MemoryVerification we just created.
    verif: MemoryVerification
    #Tips we're archiving.
    archiving: seq[VerifierIndex]

#Tests the DB's list of verifiers, tips, and a reloaded copy of the Verifications against the real one.
proc test(archived: seq[VerifierIndex], verifiersLen: int) =
    #Test the `verifications_verifiers`.
    var verifiersStr: string
    for v in 0 ..< verifiersLen:
        verifiersStr &= verifiers[v].publicKey.toString()
    assert(db.get("verifications_verifiers") == verifiersStr)

    #Test the archived tips.
    for tip in archived:
        #Make sure the original Verifications has the same tip.
        assert(verifications[tip.key].archived == int(tip.nonce))
        #Make sure the DB has the same tip.
        assert(db.get("verifications_" & tip.key) == $tip.nonce)

    #Reload the database.
    var reloaded: Verifications = newVerifications(db)

    #Test each verifier.
    for v in verifiers:
        #Grab each Verifier.
        var
            originalVerifier: Verifier = verifications[v.publicKey.toString()]
            reloadedVerifier: Verifier = reloaded[v.publicKey.toString()]

        #Test both have the same fields.
        assert(originalVerifier.key == reloadedVerifier.key)
        assert(originalVerifier.archived == reloadedVerifier.archived)

        #Test the Verifications.
        for verif in 0 .. originalVerifier.archived:
            assert(originalVerifier[verif].verifier == reloadedVerifier[verif].verifier)
            assert(originalVerifier[verif].nonce == reloadedVerifier[verif].nonce)
            assert(originalVerifier[verif].hash == reloadedVerifier[verif].hash)

        #Test the Merkle.
        if originalVerifier.archived == -1:
            assert(reloadedVerifier.merkle.hash == "".pad(48))
        else:
            assert(originalVerifier.calculateMerkle(uint(originalVerifier.archived)) == reloadedVerifier.calculateMerkle(uint(originalVerifier.archived)))

#Create 5 Verifiers.
for i in 0 ..< 5:
    verifiers.add(newMinerWallet())

#Create 1 Verification for the first Verifier.
verif = newMemoryVerificationObj(char(0).pad(48).toHash(384))
verifiers[0].sign(verif, 0)
verifications.add(verif)
assert(db.get("verifications_" & verifiers[0].publicKey.toString() & "_" & 0.toBinary()) == verif.hash.toString())

#Create 3 Verifications for the second Verifier.
for i in 0 ..< 3:
    verif = newMemoryVerificationObj(char(i).pad(48).toHash(384))
    verifiers[1].sign(verif, uint(i))
    verifications.add(verif)
    assert(db.get("verifications_" & verifiers[1].publicKey.toString() & "_" & i.toBinary()) == verif.hash.toString())

#Create 5 Verifications for the third Verifier.
for i in 0 ..< 5:
    verif = newMemoryVerificationObj(char(i).pad(48).toHash(384))
    verifiers[2].sign(verif, uint(i))
    verifications.add(verif)
    assert(db.get("verifications_" & verifiers[2].publicKey.toString() & "_" & i.toBinary()) == verif.hash.toString())

#Archive all of these (the Merkle is blank since we check that in the Merit systems, which are out of scope for this test).
archiving = @[
    newVerifierIndex(
        verifiers[0].publicKey.toString(),
        0,
        "".pad(48)
    ),
    newVerifierIndex(
        verifiers[1].publicKey.toString(),
        2,
        "".pad(48)
    ),
    newVerifierIndex(
        verifiers[2].publicKey.toString(),
        4,
        "".pad(48)
    )
]
verifications.archive(archiving)

#Test the Verifications.
test(archiving, 3)

#Add more Verifications to each person.
for i in 1 ..< 8:
    verif = newMemoryVerificationObj(char(i).pad(48).toHash(384))
    verifiers[0].sign(verif, uint(i))
    verifications.add(verif)
    assert(db.get("verifications_" & verifiers[0].publicKey.toString() & "_" & i.toBinary()) == verif.hash.toString())

for i in 3 ..< 7:
    verif = newMemoryVerificationObj(char(i).pad(48).toHash(384))
    verifiers[1].sign(verif, uint(i))
    verifications.add(verif)
    assert(db.get("verifications_" & verifiers[1].publicKey.toString() & "_" & i.toBinary()) == verif.hash.toString())

for i in 5 ..< 10:
    verif = newMemoryVerificationObj(char(i).pad(48).toHash(384))
    verifiers[2].sign(verif, uint(i))
    verifications.add(verif)
    assert(db.get("verifications_" & verifiers[2].publicKey.toString() & "_" & i.toBinary()) == verif.hash.toString())

#Add a new Verifier.
verif = newMemoryVerificationObj(char(0).pad(48).toHash(384))
verifiers[3].sign(verif, 0)
verifications.add(verif)
assert(db.get("verifications_" & verifiers[3].publicKey.toString() & "_" & 0.toBinary()) == verif.hash.toString())

#Add a blank Verifier.
discard verifications[verifiers[4].publicKey.toString()]

#Archive all of these except the second Verifier and the blank verifier.
archiving = @[
    newVerifierIndex(
        verifiers[0].publicKey.toString(),
        7,
        "".pad(48)
    ),
    newVerifierIndex(
        verifiers[2].publicKey.toString(),
        9,
        "".pad(48)
    ),
    newVerifierIndex(
        verifiers[3].publicKey.toString(),
        0,
        "".pad(48)
    )
]
verifications.archive(archiving)

#Test the Verifications.
test(archiving, 5)

#Create a Verification for the previously blank Verifier.
verif = newMemoryVerificationObj(char(0).pad(48).toHash(384))
verifiers[4].sign(verif, 0)
verifications.add(verif)
assert(db.get("verifications_" & verifiers[4].publicKey.toString() & "_" & 0.toBinary()) == verif.hash.toString())

#Archive the second verifier and the blank verifier.
archiving = @[
    newVerifierIndex(
        verifiers[1].publicKey.toString(),
        6,
        "".pad(48)
    ),
    newVerifierIndex(
        verifiers[4].publicKey.toString(),
        0,
        "".pad(48)
    )
]
verifications.archive(archiving)

#Test the Verifications.
test(archiving, 5)

echo "Finished the Database/Verifications/Verifications Test."
