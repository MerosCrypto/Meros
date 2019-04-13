#Errors lib.
import ../../../lib/Errors

#LatticeIndex object.
import ../../common/objects/LatticeIndexObj

#Entry object.
import EntryObj

#Finals lib.
import finals

#Receive object.
finalsd:
    type Receive* = ref object of Entry
        #LatticeIndex.
        index* {.final.}: LatticeIndex

#New Receive object.
func newReceiveObj*(
    index: LatticeIndex
): Receive {.forceCheck: [].} =
    result = Receive(
        index: index
    )
    result.ffinalizeIndex()

    try:
        result.descendant = EntryType.Receive
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Mint: " & e.msg)
