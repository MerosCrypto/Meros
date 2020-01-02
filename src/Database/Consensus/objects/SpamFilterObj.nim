#Errors lib.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#Tables standard lib.
import tables

type
    #VotedDifficulty object.
    VotedDifficulty* = ref object
        when defined(merosTests):
            difficulty*: Hash[384]
            votes*: int
            prev*: VotedDifficulty
            next*: VotedDifficulty
        else:
            difficulty: Hash[384]
            votes: int
            prev: VotedDifficulty
            next: VotedDifficulty

    #SpamFilter object.
    SpamFilter* = object
        when defined(merosTests):
            #Median node.
            median*: VotedDifficulty
            #Merit left of the median value.
            left*: int
            #Merit right of the median value.
            right*: int
            #Nicknames -> voted node.
            votes*: Table[uint16, VotedDifficulty]
        else:
            median: VotedDifficulty
            left: int
            right: int
            votes: Table[uint16, VotedDifficulty]

        #Starting difficulty.
        startDifficulty*: Hash[384]
        #Current median difficulty.
        difficulty*: Hash[384]

#Constructors.
func newVotedDifficulty(
    difficulty: Hash[384],
    votes: int,
    prev: VotedDifficulty,
    next: VotedDifficulty
): VotedDifficulty {.inline, forceCheck: [].} =
    VotedDifficulty(
        difficulty: difficulty,
        votes: votes,
        prev: prev,
        next: next
    )

func newSpamFilterObj*(
    difficulty: Hash[384]
): SpamFilter {.inline, forceCheck: [].} =
    SpamFilter(
        median: nil,
        left: 0,
        right: 0,

        votes: initTable[uint16, VotedDifficulty](),

        startDifficulty: difficulty,
        difficulty: difficulty
    )

#Remove the median.
func removeMedian(
    filter: var SpamFilter,
) {.forceCheck: [].} =
    if filter.median.isNil:
        return

    while filter.median.votes == 0:
        if filter.median.prev.isNil and filter.median.next.isNil:
            filter.median = nil
            filter.difficulty = filter.startDifficulty
            filter.left = 0
            filter.right = 0
            break
        elif filter.median.prev.isNil:
            filter.median.next.prev = nil
            filter.median = filter.median.next
            filter.right -= filter.median.votes
        elif filter.median.next.isNil:
            filter.median.prev.next = nil
            filter.median = filter.median.prev
            filter.left -= filter.median.votes
        else:
            filter.median.prev.next = filter.median.next
            filter.median.next.prev = filter.median.prev
            filter.median = filter.median.next
            filter.right -= filter.median.votes

#Recalculate the median.
func recalculate(
    filter: var SpamFilter
) {.forceCheck: [].} =
    #Return if there are no votes in the system.
    if filter.votes.len == 0:
        return

    #If this median wasn't voted for, remove it.
    filter.removeMedian()

    #Make sure median is accurate.
    while filter.left > filter.right:
        if filter.right + filter.median.votes < filter.left:
            filter.left -= filter.median.prev.votes
            filter.right += filter.median.votes
            filter.median = filter.median.prev
            filter.removeMedian()
        else:
            break

    while filter.right > filter.left:
        if filter.left + filter.median.votes <= filter.right:
            filter.left += filter.median.votes
            filter.right -= filter.median.next.votes
            filter.median = filter.median.next
            filter.removeMedian()
        else:
            break

    #Update the difficulty.
    if filter.median.isNil:
        filter.difficulty = filter.startDifficulty
    else:
        filter.difficulty = filter.median.difficulty

#Handle the Merit change that comes with a new Block.
func handleBlock*(
    filter: var SpamFilter,
    incd: uint16,
    incdMerit: int
) {.forceCheck: [].} =
    if ((incdMerit div 50) != ((incdMerit - 1) div 50)) and filter.votes.hasKey(incd):
        try:
            inc(filter.votes[incd].votes)
            if filter.votes[incd].difficulty < filter.difficulty:
                inc(filter.left)
            elif filter.votes[incd] == filter.median:
                discard
            else:
                inc(filter.right)
        except KeyError as e:
            doAssert(false, "Couldn't get a value by a key we confirmed we have: " & e.msg)

        filter.recalculate()

func handleBlock*(
    filter: var SpamFilter,
    incd: uint16,
    incdMerit: int,
    decd: uint16,
    decdMerit: int
) {.forceCheck: [].} =
    try:
        if ((incdMerit div 50) != ((incdMerit - 1) div 50)) and filter.votes.hasKey(incd):
            inc(filter.votes[incd].votes)
            if filter.votes[incd].difficulty < filter.difficulty:
                inc(filter.left)
            elif filter.votes[incd] == filter.median:
                discard
            else:
                inc(filter.right)
    except KeyError as e:
        doAssert(false, "Couldn't get a value by a key we confirmed we have: " & e.msg)

    try:
        if ((decdMerit div 50) != ((decdMerit + 1) div 50)) and filter.votes.hasKey(decd):
            dec(filter.votes[decd].votes)
            if filter.votes[decd].difficulty < filter.difficulty:
                dec(filter.left)
            elif filter.votes[decd] == filter.median:
                discard
            else:
                dec(filter.right)
    except KeyError as e:
        doAssert(false, "Couldn't get a value by a key we confirmed we have: " & e.msg)

    filter.recalculate()

#Update a holder's vote.
func update*(
    filter: var SpamFilter,
    holder: uint16,
    merit: int,
    difficulty: Hash[384]
) {.forceCheck: [].} =
    #Calculate the holder's votes.
    var votes: int = merit div 50

    #Return if the holder doesn't have votes.
    if votes == 0:
        return

    #If this is the first vote, set median/difficulty and return.
    if filter.median.isNil:
        filter.median = newVotedDifficulty(difficulty, votes, nil, nil)
        filter.difficulty = difficulty
        filter.votes[holder] = filter.median
        return

    #Remove the holder's Merit from their existing vote.
    if filter.votes.hasKey(holder):
        try:
            filter.votes[holder].votes -= votes
            if filter.votes[holder].difficulty < filter.median.difficulty:
                filter.left -= votes
            elif filter.votes[holder].difficulty > filter.median.difficulty:
                filter.right -= votes
        except KeyError as e:
            doAssert(false, "Couldn't get a value by a key we confirmed we have: " & e.msg)

    #Find the node matching the new vote, adding it if needed.
    var curr: VotedDifficulty = filter.median
    if difficulty < filter.difficulty:
        filter.left += votes

        while not curr.prev.isNil:
            if curr.prev.difficulty < difficulty:
                break
            curr = curr.prev

        if curr.difficulty == difficulty:
            filter.votes[holder] = curr
            curr.votes += votes
        else:
            var shifted: VotedDifficulty = curr.prev
            curr.prev = newVotedDifficulty(difficulty, votes, shifted, curr)
            filter.votes[holder] = curr.prev
            if not shifted.isNil:
                shifted.next = curr.prev
    elif difficulty > filter.difficulty:
        filter.right += votes

        while not curr.next.isNil:
            if curr.next.difficulty > difficulty:
                break
            curr = curr.next

        if curr.difficulty == difficulty:
            filter.votes[holder] = curr
            curr.votes += votes
        else:
            var shifted: VotedDifficulty = curr.next
            curr.next = newVotedDifficulty(difficulty, votes, curr, shifted)
            filter.votes[holder] = curr.next
            if not shifted.isNil:
                shifted.prev = curr.next
    else:
        filter.votes[holder] = curr
        curr.votes += votes

    #Recalculate the median.
    filter.recalculate()
