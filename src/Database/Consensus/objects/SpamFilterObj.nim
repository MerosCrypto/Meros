#[
As a note about the algorithms used in this file:
This was originally done with a LinkedList algorithm.
Not only was it harder to write, it was slower than the seq algorithm.
That said, this may be optimal as a binary tree.
That said, this is an extremely low priority.
]#

import tables

import ../../../lib/Errors
import ../../Merit/objects/StateObj

type
  VotedDifficulty* = ref object
    when defined(merosTests):
      difficulty*: uint16
      votes*: int
    else:
      difficulty: uint16
      votes: int

  SpamFilter* = object
    when defined(merosTests):
      #Median difficulty.
      medianPos*: int
      #Votes left of the median value.
      left*: int
      #Votes right of the median value.
      right*: int
      #Voted Difficulties.
      difficulties*: seq[VotedDifficulty]
      #Nicknames -> VotedDifficulty.
      votes*: Table[uint16, VotedDifficulty]
    else:
      medianPos: int
      left: int
      right: int
      difficulties: seq[VotedDifficulty]
      votes: Table[uint16, VotedDifficulty]

    #Initial difficulty.
    initialDifficulty*: uint16
    #Current difficulty.
    difficulty*: uint16

func newVotedDifficulty(
  difficulty: uint16,
  votes: int
): VotedDifficulty {.inline, forceCheck: [].} =
  VotedDifficulty(
    difficulty: difficulty,
    votes: votes
  )

func newSpamFilterObj*(
  difficulty: uint16
): SpamFilter {.inline, forceCheck: [].} =
  SpamFilter(
    medianPos: -1,
    left: 0,
    right: 0,
    difficulties: @[],

    votes: initTable[uint16, VotedDifficulty](),

    initialDifficulty: difficulty,
    difficulty: difficulty
  )

#This function shouldn't be needed due to .difficulty.
#If it is needed to calculate the new median, it shouldn't be exported.
func median*(
  filter: SpamFilter
): VotedDifficulty {.inline, forceCheck: [].} =
  filter.difficulties[filter.medianPos]

#Access the element before the median element.
func prevMedian*(
  filter: SpamFilter
): VotedDifficulty {.inline, forceCheck: [].} =
  filter.difficulties[filter.medianPos - 1]

#Access the element after the median element.
func nextMedian*(
  filter: SpamFilter
): VotedDifficulty {.inline, forceCheck: [].} =
  filter.difficulties[filter.medianPos + 1]

#Remove a difficulty.
#Used when a Merit Holder loses all Unlocked Merit.
func remove(
  filter: var SpamFilter,
  difficulty: VotedDifficulty
) {.forceCheck: [].} =
  var d: int = 0
  while d < filter.difficulties.len:
    if difficulty == filter.difficulties[d]:
      break
    inc(d)
  filter.difficulties.delete(d)

  #Update the median accordingly.
  if d < filter.medianPos:
    dec(filter.medianPos)
  elif filter.medianPos == d:
    if filter.difficulties.len == 0:
      filter.medianPos = -1
      filter.difficulty = filter.initialDifficulty
      filter.left = 0
      filter.right = 0
    elif d == filter.difficulties.len:
      dec(filter.medianPos)
      filter.difficulty = filter.median.difficulty
      filter.left -= filter.median.votes
    else:
      filter.difficulty = filter.median.difficulty
      filter.right -= filter.median.votes

#Recalculate the median.
func recalculate(
  filter: var SpamFilter
) {.forceCheck: [].} =
  #Return if there are no votes in the system.
  if filter.votes.len == 0:
    return

  while filter.left > filter.right:
    if filter.right + filter.median.votes < filter.left:
      filter.left -= filter.prevMedian.votes
      filter.right += filter.median.votes
      filter.medianPos -= 1
    else:
      break
  while filter.right > filter.left:
    if filter.left + filter.median.votes <= filter.right:
      filter.left += filter.median.votes
      filter.right -= filter.nextMedian.votes
      filter.medianPos += 1
    else:
      break

  #Update the difficulty.
  filter.difficulty = filter.median.difficulty

#Remove a holder's vote.
proc remove*(
  filter: var SpamFilter,
  holder: uint16,
  merit: int
) {.forceCheck: [].} =
  if filter.votes.hasKey(holder):
    #Remove the existing votes.
    var votes: int = merit div 50
    try:
      filter.votes[holder].votes -= votes
      if filter.votes[holder].difficulty < filter.median.difficulty:
        filter.left -= votes
      elif filter.votes[holder].difficulty > filter.median.difficulty:
        filter.right -= votes

      if filter.votes[holder].votes == 0:
        filter.remove(filter.votes[holder])
    except KeyError as e:
      panic("Couldn't get a value by a key we confirmed we have: " & e.msg)

    #Delete the entry in the votes table.
    filter.votes.del(holder)

    #If there's votes left, recalculate the median.
    if filter.medianPos != -1:
      filter.recalculate()

#Update a holder's vote.
proc update*(
  filter: var SpamFilter,
  state: State,
  holder: uint16,
  difficulty: uint16
) {.forceCheck: [].} =
  #Calculate the holder's votes.
  var votes: int = state.merit[holder] div 50
  if (state.statuses[holder] == MeritStatus.Locked) or (votes == 0):
    return

  #If this is the first vote, set median/difficulty and return.
  if filter.medianPos == -1:
    filter.medianPos = 0
    filter.difficulties.add(newVotedDifficulty(difficulty, votes))
    filter.difficulty = difficulty
    filter.votes[holder] = filter.median
    return

  #Remove the holder's Merit from their existing vote.
  filter.remove(holder, state.merit[holder])

  #If we just removed the median, create a new one.
  if filter.medianPos == -1:
    filter.medianPos = 0
    filter.difficulties = @[newVotedDifficulty(difficulty, votes)]
    filter.votes[holder] = filter.difficulties[0]
  else:
    #Find the node matching the new vote, adding it if needed.
    var curr: int = filter.medianPos
    if difficulty < filter.difficulty:
      filter.left += votes

      while curr != 0:
        if filter.difficulties[curr - 1].difficulty < difficulty:
          break
        dec(curr)

      if filter.difficulties[curr].difficulty == difficulty:
        filter.votes[holder] = filter.difficulties[curr]
        filter.difficulties[curr].votes += votes
      else:
        filter.difficulties.insert(newVotedDifficulty(difficulty, votes), curr)
        filter.votes[holder] = filter.difficulties[curr]
        inc(filter.medianPos)
    elif difficulty > filter.difficulty:
      filter.right += votes

      while curr != filter.difficulties.len - 1:
        if filter.difficulties[curr + 1].difficulty > difficulty:
          break
        inc(curr)

      if filter.difficulties[curr].difficulty == difficulty:
        filter.votes[holder] = filter.difficulties[curr]
        filter.difficulties[curr].votes += votes
      else:
        filter.difficulties.insert(newVotedDifficulty(difficulty, votes), curr + 1)
        filter.votes[holder] = filter.difficulties[curr + 1]
    else:
      filter.votes[holder] = filter.difficulties[curr]
      filter.difficulties[curr].votes += votes

  #Recalculate the median.
  filter.recalculate()

proc handleBlock*(
  filter: var SpamFilter,
  state: State,
  changes: StateChanges,
  difficulties: Table[uint16, uint16]
) {.forceCheck: [].} =
  #Only update votes if there's actually a Merit change.
  if (changes.decd == -1) or (changes.incd != uint16(changes.decd)):
    var incdMerit: int = 0
    if state.statuses[changes.incd] != MeritStatus.Locked:
      incdMerit = state.merit[changes.incd]
    if (incdMerit mod 50 == 0) and (incdMerit != 0) and filter.votes.hasKey(changes.incd):
      try:
        inc(filter.votes[changes.incd].votes)
        if filter.votes[changes.incd].difficulty < filter.difficulty:
          inc(filter.left)
        elif filter.votes[changes.incd] == filter.median:
          discard
        else:
          inc(filter.right)
      except KeyError as e:
        panic("Couldn't get a value by a key we confirmed we have: " & e.msg)

    if changes.decd != -1:
      var
        decd: uint16 = uint16(changes.decd)
        decdMerit: int = state.merit[decd]

      try:
        if (decdMerit mod 50 == 49) and filter.votes.hasKey(decd):
          dec(filter.votes[decd].votes)
          if filter.votes[decd].difficulty < filter.difficulty:
            dec(filter.left)
          elif filter.votes[decd] == filter.median:
            discard
          else:
            dec(filter.right)

          if filter.votes[decd].votes == 0:
            filter.remove(filter.votes[decd])
          if decdMerit div 50 == 0:
            filter.votes.del(decd)
      except KeyError as e:
        panic("Couldn't get a value by a key we confirmed we have: " & e.msg)

  filter.recalculate()

  #Remove votes from Locked Merit; add back votes of no-longer-Locked Merit.
  for holder in changes.locked:
    filter.remove(holder, state.merit[holder])
  for holder in changes.pending:
    try:
      filter.update(state, holder, difficulties[holder])
    except KeyError:
      discard
