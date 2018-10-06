#Node object.
import NodeObj

#Hash library.
import ../../../lib/Hash

#Finals lib.
import finals

#Merit Removal object.
finalsd:
    type MeritRemoval* = ref object of Node
        #Verification of a spend.
        first* {.final.}: Hash[512]
        #Verification of a double spend.
        second* {.final.}: Hash[512]

#New MeritRemoval object.
func newMeritRemovalObj*(
    first: Hash[512],
    second: Hash[512]
): MeritRemoval {.raises: [FinalAttributeError].} =
    result = MeritRemoval(
        first: first,
        second: second
    )
    result.descendant = NodeType.MeritRemoval
