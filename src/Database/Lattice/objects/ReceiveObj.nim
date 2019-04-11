#Entry object.
import EntryObj

#LatticeIndex object.
import ../../common/objects/LatticeIndexObj

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
): Receive {.raises: [FinalAttributeError].} =
    result = Receive(
        index: index
    )
    result.ffinalizeIndex()

    result.descendant = EntryType.Receive
