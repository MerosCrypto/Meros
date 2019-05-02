#Errors.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#DB Function Box object.
import ../../objects/GlobalFunctionBoxObj

#Merkle lib.
import ../common/Merkle

#VerificationsIndex and VerifierRecord object.
import ../common/objects/VerificationsIndexObj
import ../common/objects/VerifierRecordObj
export VerificationsIndex

#Verification and Verifier libs.
import Verification
import Verifier
export Verification
export Verifier

#Verifications object.
import objects/VerificationsObj
export VerificationsObj

#Seq utils standard lib.
import sequtils

#Tables standard lib.
import tables

#Constructor wrapper.
proc newVerifications*(
    db: DatabaseFunctionBox
): Verifications {.forceCheck: [].} =
    newVerificationsObj(db)

#Add a Verification.
proc add*(
    verifs: Verifications,
    verif: Verification
) {.forceCheck: [
    GapError,
    DataExists,
    MeritRemoval
], fcBoundsOverride.} =
    try:
        verifs[verif.verifier].add(verif)
    except GapError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e
    except MeritRemoval as e:
        fcRaise e

#Add a MemoryVerification.
proc add*(
    verifs: Verifications,
    verif: MemoryVerification
) {.forceCheck: [
    GapError,
    BLSError,
    DataExists,
    MeritRemoval
], fcBoundsOverride.} =
    try:
        verifs[verif.verifier].add(verif)
    except GapError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e
    except MeritRemoval as e:
        fcRaise e

#For each provided Record, archive all Verifications from the account's last archived to the provided nonce.
proc archive*(
    verifs: Verifications,
    records: seq[VerifierRecord]
) {.forceCheck: [], fcBoundsOverride.} =
    #Iterate over every Record.
    for record in records:
        #Delete them from the seq.
        try:
            verifs[record.key].verifications.delete(
                0,
                record.nonce - verifs[record.key].verifications[0].nonce
            )
        except IndexError as e:
            doAssert(false, "Tried to archive Verifications from a Verifier without any pending Verifications: " & e.msg)

        #Reset the Merkle.
        verifs[record.key].merkle = newMerkle()
        for verif in verifs[record.key].verifications:
            verifs[record.key].merkle.add(verif.hash)

        #Update the archived field.
        verifs[record.key].archived = record.nonce

        #Update the DB.
        try:
            verifs.db.put("verifications_" & record.key.toString(), $record.nonce)
        except DBWriteError as e:
            doAssert(false, "Couldn't save a Verifier's tip to the Database: " & e.msg)
