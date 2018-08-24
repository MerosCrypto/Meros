#Lattice libs.
import NodeObj

#Merit Removal object.
type MeritRemoval* = ref object of Node
    #Verification of a spend.
    first: string
    #Verification of a double spend.
    second: string

#New MeritRemoval object.
proc newMeritRemovalObj*(first: string, second: string): MeritRemoval {.raises: [].} =
    MeritRemoval(
        descendant: NodeMeritRemoval,
        first: first,
        second: second
    )

#Getters.
proc getFirst*(mr: MeritRemoval): string {.raises: [].} =
    mr.first
proc getSecond*(mr: MeritRemoval): string {.raises: [].} =
    mr.second
