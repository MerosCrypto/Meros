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
        input* {.final.}: LatticeIndex

#New Receive object.
func newReceiveObj*(
    input: LatticeIndex
): Receive {.forceCheck: [].} =
    result = Receive(
        input: input
    )
    result.ffinalizeInput()

    try:
        result.descendant = EntryType.Receive
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Mint: " & e.msg)
