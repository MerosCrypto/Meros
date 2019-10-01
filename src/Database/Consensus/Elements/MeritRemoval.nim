#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#MeritRemoval object.
import objects/MeritRemovalObj
export MeritRemovalObj

#MeritRemoval serialize libs.
import ../../../Network/Serialize/SerializeCommon
import ../../../Network/Serialize/Consensus/SerializeMeritRemoval

#Constructor wrappers.
func newMeritRemoval*(
    nick: uint16,
    partial: bool,
    element1: Element,
    element2: Element
): MeritRemoval {.inline, forceCheck: [].} =
    newMeritRemovalObj(
        nick,
        partial,
        element1,
        element2
    )

func newSignedMeritRemoval*(
    nick: uint16,
    partial: bool,
    element1: Element,
    element2: Element,
    signature: BLSSignature
): SignedMeritRemoval {.inline, forceCheck: [].} =
    newSignedMeritRemovalObj(
        nick,
        partial,
        element1,
        element2,
        signature
    )

#Calculate the MeritRemoval's merkle leaf hash.
proc merkle*(
    mr: MeritRemoval
): Hash[384] {.forceCheck: [].} =
    Blake384(char(MERIT_REMOVAL_PREFIX) & mr.serialize())

#Calculate the MeritRemoval's aggregation info.
#[
proc agInfo*(
    mr: MeritRemoval
): BLSAggregationInfo {.forceCheck: [].} =
    try:
        #If this is a partial MeritRemoval, the signature is the second Element's.
        if mr.partial:
            result = newBLSAggregationInfo(mr.holder, mr.element2.serializeWithoutHolder())
        #Else, it's both Elements' signatures aggregated.
        else:
            result = @[
                newBLSAggregationInfo(mr.holder, mr.element1.serializeWithoutHolder()),
                newBLSAggregationInfo(mr.holder, mr.element2.serializeWithoutHolder())
            ].aggregate()
    except BLSError as e:
        doAssert(false, "Failed to create the MeritRemoval's AggregationInfo: " & e.msg)
]#
