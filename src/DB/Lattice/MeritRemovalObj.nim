#Lattice libs.
import Node
import Verification

#Merit Removal object.
type MeritRemoval* = ref object of Node
    #Verification of a spend.
    first: Verification
    #Verification of a double spend.
    second: Verification

#New MeritRemoval object.
proc newMeritRemovalObj*(first: Verification, second: Verification): MeritRemoval =
    result = MeritRemoval(
        first: first,
        second: second
    )

#Getters.
proc getFirst*(mr: MeritRemoval): Verification =
    mr.first
proc getSecond*(mr: MeritRemoval): Verification =
    mr.second
