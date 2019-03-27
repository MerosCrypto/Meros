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
    For each, add the verifier.

On Verifier creation:
    If the Verifier doesn't exist, add them to `verifiersStr` (if they're not in `verifiersSeq`) and save it.
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


import strutils


#Tests the DB's list of verifiers, tips, and a reloaded copy of the Verifications against the real one.
proc test(archived: seq[VerifierIndex]) =
    #Test the `verifications_verifiers`.
    var verifiersStr: string
    for v in verifiers:
        verifiersStr &= v.publicKey.toString()
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
        assert(originalVerifier.height == reloadedVerifier.height)
        assert(originalVerifier.archived == reloadedVerifier.archived)

        #Test the Verifications.
        for verif in 0 .. originalVerifier.archived:
            assert(originalVerifier[verif].verifier == reloadedVerifier[verif].verifier)
            assert(originalVerifier[verif].nonce == reloadedVerifier[verif].nonce)
            assert(originalVerifier[verif].hash == reloadedVerifier[verif].hash)

        #Test the Merkle.
        if originalVerifier.archived == -1:
            assert(reloadedVerifier.merkle.hash == "".pad(64))
        else:
            assert(originalVerifier.calculateMerkle(uint(originalVerifier.archived)) == reloadedVerifier.calculateMerkle(uint(originalVerifier.archived)))

#Create 3 Verifiers.
for i in 0 ..< 3:
    verifiers.add(newMinerWallet())

#Create 1 Verification for the first Verifier.
verif = newMemoryVerificationObj(char(0).pad(64).toHash(512))
verifiers[0].sign(verif, 0)
verifications.add(verif)
assert(db.get("verifications_" & verifiers[0].publicKey.toString() & "_" & 0.toBinary()) == verif.hash.toString())

#Create 3 Verifications for the second Verifier.
for i in 0 ..< 3:
    verif = newMemoryVerificationObj(char(i).pad(64).toHash(512))
    verifiers[1].sign(verif, uint(i))
    verifications.add(verif)
    assert(db.get("verifications_" & verifiers[1].publicKey.toString() & "_" & i.toBinary()) == verif.hash.toString())

#Create 5 Verifications for the third Verifier.
for i in 0 ..< 5:
    verif = newMemoryVerificationObj(char(i).pad(64).toHash(512))
    verifiers[2].sign(verif, uint(i))
    verifications.add(verif)
    assert(db.get("verifications_" & verifiers[2].publicKey.toString() & "_" & i.toBinary()) == verif.hash.toString())

#Archive all of these (the Merkle is blank since we check that in the Merit systems, which are out of scope for this test).
archiving = @[
    newVerifierIndex(
        verifiers[0].publicKey.toString(),
        0,
        "".pad(64)
    ),
    newVerifierIndex(
        verifiers[1].publicKey.toString(),
        2,
        "".pad(64)
    ),
    newVerifierIndex(
        verifiers[2].publicKey.toString(),
        4,
        "".pad(64)
    )
]
verifications.archive(archiving)

#Test the Verifications.
test(archiving)

echo "Finished the Database/Verifications/Verifications Test."
