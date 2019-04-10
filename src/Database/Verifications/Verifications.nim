#Errors.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#BN lib.
import BN

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Index and VerifierIndex objects.
import ../common/objects/IndexObj
import ../common/objects/VerifierIndexObj

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
) {.raises: [MerosIndexError, DBError].} =
    verifs[verif.verifier.toString()].add(verif)

#For each provided Index, archive all Verifications from the account's last archived to the provided nonce.
proc archive*(
    verifs: Verifications,
    indexes: seq[VerifierIndex]
) {.raises: [DBError].} =
    #Iterate over every Index.
    for index in indexes:
        #Delete them from the seq.
        verifs[index.key].verifications.delete(
            0,
            index.nonce - verifs[index.key].verifications[0].nonce
        )

        #Update the Verifier.
        verifs[index.key].archived = index.nonce

        #Update the DB.
        verifs.db.put("verifications_" & index.key, $index.nonce)
