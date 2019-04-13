#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Entry object.
import EntryObj

#Finals lib.
import finals

#Data object.
finalsd:
    type Data* = ref object of Entry
        #Data included in the Entry.
        data* {.final.}: string

        #Proof this isn't spam.
        proof* {.final.}: int
        #Argon hash.
        argon* {.final.}: ArgonHash

#New Data object.
func newDataObj*(
    data: string
): Data {.forceCheck: [].} =
    result = Data(
        data: data
    )
    result.ffinalizeData()

    try:
        result.descendant = EntryType.Data
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Data: " & e.msg)
