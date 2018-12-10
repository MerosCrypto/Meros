#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#BLS lib.
import ../../../lib/BLS

#Finals lib.
import finals

#Verifier object.
finalsd:
    type Verifier* = ref object of RootObj
        #Chain owner.
        key* {.final.}: string
        #Verifier height.
        height*: uint
        #seq of the Verifications.
        verifications*: seq[Verification]

discard """
#Calculate the aggregate signature.
proc calculateSig*(verifs: Verifications) {.raises: [BLSError].} =
    #If there's no verifications...
    if verifs.verifications.len == 0:
        #Set a 0'd out signature.
        try:
            verifs.aggregate = newBLSSignature(char(0).repeat(96))
        except:
            raise newException(BLSError, "Couldn't aggregate the signature for the Verifications.")
        return

    #Declare a seq for the Signatures.
    var sigs: seq[BLSSignature]
    #Put every signature in the seq.
    for verif in verifs.verifications:
        sigs.add(verif.signature)
    #Set the aggregate.
    verifs.aggregate = sigs.aggregate()

#Verify the aggregate signature.
proc verify*(verifs: Verifications): bool {.raises: [BLSError].} =
    #If there's no verifications...
    if verifs.verifications.len == 0:
        return true

    #Create the Aggregation Infos.
    var agInfos: seq[BLSAggregationInfo] = @[]
    for verif in verifs.verifications:
        agInfos.add(
            newBLSAggregationInfo(verif.verifier, verif.hash.toString())
        )

    #Add the aggregated Aggregation Infos to the signature.
    verifs.aggregate.setAggregationInfo(agInfos.aggregate())

    #Verify the signature.
    result = verifs.aggregate.verify()
"""
