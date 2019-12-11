#Errors lib.
import ../../../lib/Errors

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Verification object.
import objects/VerificationObj
export VerificationObj

#Serialize lib.
import ../../../Network/Serialize/Consensus/SerializeVerification

#Sign a Verification.
proc sign*(
    miner: MinerWallet,
    verif: SignedVerification
) {.forceCheck: [].} =
    try:
        #Set the holder.
        verif.holder = miner.nick
        #Sign the hash of the Verification.
        verif.signature = miner.sign(verif.serializeWithoutHolder())
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when signing a Verification: " & e.msg)
