import algorithm
import sequtils
import tables

import ../../lib/Errors

import State

import objects/EpochsObj
export EpochsObj

type Reward* = object
  nick*: uint16
  score*: uint64

#Public due to the tests.
func newReward*(
  nick: uint16,
  score: uint64
): Reward {.inline, forceCheck: [].} =
  Reward(
    nick: nick,
    score: score
  )

#Calculate what share each holder deserves of the minted Meros.
proc calculateRewards*(
  state: State,
  txsVerifiers: seq[seq[uint16]],
  removed: set[uint16]
): seq[Reward] {.forceCheck: [].} =
  #If the Epoch was empty, do nothing.
  if txsVerifiers.len == 0:
    return @[]

  var
    #Total Merit behind an Transaction.
    weight: int
    #Score of a holder.
    scores: Table[uint16, uint64] = initTable[uint16, uint64]()
    #Total score.
    total: uint64
    #Total normalized score.
    normalized: int

  #Find out how many Verifications for verified Transactions were created by each Merit Holder.
  for verifiers in txsVerifiers:
    #Clear the loop variable.
    weight = 0

    #Iterate over every holder who verified a tx.
    for holder in verifiers:
      if not removed.contains(holder):
        #Add their Merit to the Transaction's weight.
        weight += state[holder, state.processedBlocks]

    #Make sure the Transaction was verified.
    if weight < state.protocolThreshold():
      continue

    #If it was, increment every verifier's score.
    for holder in verifiers:
      if not scores.hasKey(holder):
        scores[holder] = 0
      try:
        scores[holder] += 1
      except KeyError as e:
        panic("Couldn't grab the score of a holder despite ensuring they exist: " & e.msg)

  #Make sure at least one Transaction didn't default.
  if scores.len == 0:
    return @[]

  #Multiply every score by how much Merit the holder has.
  for malicious in removed:
    scores.del(malicious)

  try:
    for holder in scores.keys():
      scores[holder] = scores[holder] * uint64(state[holder, state.processedBlocks])
      #Add the update score to the total.
      total += scores[holder]
  except KeyError as e:
    panic("Couldn't update a holder's score despite grabbing the holder by scores.keys(): " & e.msg)

  #Turn the table into a seq.
  result = newSeq[Reward]()
  try:
    for holder in scores.keys():
      result.add(
        newReward(
          holder,
          scores[holder]
        )
      )
  except KeyError as e:
    panic("Couldn't grab the score of a holder grabbed from scores.keys(): " & e.msg)

  #Sort them by greatest score.
  result.sort(
    proc (
      x: Reward,
      y: Reward
    ): int {.forceCheck: [].} =
      if x.score > y.score:
        result = 1
      elif x.score == y.score:
        if x.nick < y.nick:
          return 1
        elif x.nick == y.nick:
          panic("Epochs generated two rewards for the same nick.")
        else:
          return -1
      else:
        result = -1
    , SortOrder.Descending
  )

  #Delete everything after 100.
  if result.len > 100:
    result.delete(100, result.len - 1)

  #Normalize each holder to a share of 1000.
  for i in 0 ..< result.len:
    result[i].score = result[i].score * 1000 div total
    normalized += int(result[i].score)

  #If the score isn't a perfect 1000, attribute everything left over to the top verifier.
  if normalized < 1000:
    result[0].score += uint64(1000 - normalized)

  #Delete 0 scores.
  while result[^1].score == 0:
    result.delete(result.len - 1)
