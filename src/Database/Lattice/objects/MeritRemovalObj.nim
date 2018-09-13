#Node object.
import NodeObj

#Hash library.
import ../../../lib/Hash

#SetOnce lib.
import SetOnce

#Merit Removal object.
type MeritRemoval* = ref object of Node
    #Verification of a spend.
    first*: SetOnce[Hash[512]]
    #Verification of a double spend.
    second*: SetOnce[Hash[512]]

#New MeritRemoval object.
proc newMeritRemovalObj*(first: Hash[512], second: Hash[512]): MeritRemoval {.raises: [ValueError].} =
    result = MeritRemoval()
    result.descendant.value = NodeType.MeritRemoval
    result.first.value = first
    result.second.value = second
