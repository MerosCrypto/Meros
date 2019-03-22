#Errors.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#BN lib.
import BN

#Hash lib.
import ../../lib/Hash

#BLS lib.
import ../../lib/BLS

#Index object.
import ../common/objects/IndexObj

#VerifierIndex object (not under common as this is solely used for archival, which is triggered by Merit).
import ../Merit/objects/VerifierIndexObj

#DB Function Box object.
import ../../objects/GlobalFunctionBoxObj

#Verification and Verifier libs.
import Verification
import Verifier
export Verification
export Verifier

#Verifications object.
import objects/VerificationsObj
export VerificationsObj

#Sequtils standard lib.
import sequtils

#Tables standard lib.
import tables

#Finals lib.
import finals

#Constructor wrapper.
proc newVerifications*(db: DatabaseFunctionBox): Verifications {.raises: [].} =
    newVerificationsObj(db)

#Add a Verification.
proc add*(
    verifs: Verifications,
    verif: Verification
) {.raises: [KeyError, MerosIndexError, LMDBError].} =
    verifs[verif.verifier.toString()].add(verif)

#For each provided Index, archive all Verifications from the account's last archived to the provided nonce.
proc archive*(
    verifs: Verifications,
    indexes: seq[VerifierIndex],
    archived: uint
) {.raises: [KeyError, LMDBError].} =
    #Iterate over every Index.
    for index in indexes:
        #Delete them from the seq.
        verifs[index.key].verifications.delete(
            0,
            int(index.nonce - verifs[index.key].verifications[0].nonce)
        )

        #Update the Verifier.
        verifs[index.key].archived = int(index.nonce)

        #Update the DB.
        verifs.db.put("verifications_" & index.key.pad(48), $index.nonce)
