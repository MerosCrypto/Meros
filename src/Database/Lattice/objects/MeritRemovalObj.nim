#Lattice libs.
import NodeObj
import VerificationObj

#Merit Removal object.
type MeritRemoval* = ref object of Node
    #Verification of a spend.
    first: Verification
    #Verification of a double spend.
    second: Verification

#New MeritRemoval object.
proc newMeritRemovalObj*(first: Verification, second: Verification): MeritRemoval {.raises: [].} =
    MeritRemoval(
        first: first,
        second: second
    )

#Getters.
proc getFirst*(mr: MeritRemoval): Verification {.raises: [].} =
    mr.first
proc getSecond*(mr: MeritRemoval): Verification {.raises: [].} =
    mr.second
