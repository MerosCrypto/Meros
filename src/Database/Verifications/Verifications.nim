#Errors.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#DB Function Box object.
import ../../objects/GlobalFunctionBoxObj

#VerificationsIndex and VerifierRecord object.
import ../common/objects/VerificationsIndexObj
import ../common/objects/VerifierRecordObj

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
    verifs: var Verifications,
    verif: Verification
) {.forceCheck: [
    IndexError,
    GapError,
    MeritRemoval
].} =
    try:
        verifs[verif.verifier].add(verif)
    except IndexError as e:
        raise e
    except GapError as e:
        raise e
    except MeritRemoval as e:
        raise e

#For each provided Record, archive all Verifications from the account's last archived to the provided nonce.
proc archive*(
    verifs: var Verifications,
    records: seq[VerifierRecord]
) {.forceCheck: [].} =
    #Iterate over every Record.
    for record in records:
        #Delete them from the seq.
        verifs[record.key].verifications.delete(
            0,
            record.nonce - verifs[record.key].verifications[0].nonce
        )

        #Update the Verifier.
        verifs[record.key].archived = record.nonce

        #Update the DB.
        try:
            verifs.db.put("verifications_" & record.key.toString(), $record.nonce)
        except DBWriteError as e:
            doAssert(false, "Couldn't save a Verifier's tip to the Database: " & e.msg)
