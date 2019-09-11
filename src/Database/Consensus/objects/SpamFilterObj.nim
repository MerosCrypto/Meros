#Errors lib.
import ../../../lib/Errors

#Hash lib/
import ../../../lib/Hash

#Finals lib.
import finals

#SpamFilter object.
finalsd:
    type SpamFilter* = ref object
        difficulty* {.final.}: Hash[384]

#Constructor.
func newSpamFilterObj*(
    difficulty: Hash[384]
): SpamFilter {.forceCheck: [].} =
    result = SpamFilter(
        difficulty: difficulty
    )
    result.ffinalizeDifficulty()
