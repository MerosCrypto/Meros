import sequtils
import algorithm
import deques
import tables

import ../../lib/[Errors, Hash]

import ../Consensus/Elements/objects/[VerificationPacketObj, MeritRemovalObj]

import Block, Blockchain, State

import objects/EpochsObj
export EpochsObj

#This shift does three things:
# - Adds the newest set of Verifications.
# - Stores the oldest Epoch to be returned.
# - Removes the oldest Epoch from Epochs.
proc shift*(
  epochs: var Epochs,
  newBlock: Block
): Epoch {.forceCheck: [].} =
  logDebug "Epochs processing Block", hash = newBlock.header.hash

  var
    #New Epoch for any Verifications belonging to Transactions that aren't in an older Epoch.
    newEpoch: Epoch = newEpoch()
    #Epoch the hash is in.
    e: int

  #Loop over every packet.
  for packet in newBlock.body.packets:
    #Find out what Epoch the hash is in.
    e = 0
    while e < 5:
      try:
        if epochs[e].hasKey(packet.hash):
          break
      except IndexError as ex:
        panic("Couldn't access Epoch " & $e & ", despite iterating from 0 up to 5: " & ex.msg)

      #If it's not in any, add the packet to the new Epoch.
      if e == 4:
        #Create a seq for the Transaction.
        newEpoch.register(packet.hash)

        #Add the packet.
        newEpoch.add(packet)

      #Increment e.
      inc(e)

    #If it was in an existing Epoch, add it to said Epoch.
    if e != 5:
      try:
        epochs[e].add(packet)
      except IndexError as ex:
        panic("Couldn't access Epoch " & $e & ", despite confirming the Epoch existed: " & ex.msg)

  #Return the popped Epoch.
  result = epochs.shift(newEpoch)

#Constructor. Below shift as it calls shift.
proc newEpochs*(
  blockchain: Blockchain
): Epochs {.forceCheck: [].} =
  #Create the Epochs objects.
  result = newEpochsObj()

  #Regenerate the Epochs. To do this, we shift the last 10 blocks. Why?
  #We want to regenerate the Epochs for the last 5, but we need to regenerate the 5 before that so late elements aren't labelled as first appearances.
  for b in max(blockchain.height - 10, 0) ..< blockchain.height:
    try:
      discard result.shift(blockchain[b])
    except IndexError as e:
      panic("Couldn't shift the last 10 Blocks from the chain: " & e.msg)

#Calculate what share each holder deserves of the minted Meros.
proc calculate*(
  epoch: Epoch,
  state: var State,
  removed: Table[uint16, MeritRemoval]
): seq[Reward] {.forceCheck: [].} =
  #If the epoch is empty, do nothing.
  if epoch.len == 0:
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
  for tx in epoch.keys():
    #Clear the loop variable.
    weight = 0

    try:
      #Iterate over every holder who verified a tx.
      for holder in epoch[tx]:
        if not removed.hasKey(holder):
          #Add their Merit to the Transaction's weight.
          weight += state[holder, state.processedBlocks]
    except KeyError as e:
      panic("Couldn't grab the verifiers for a hash in the Epoch grabbed from epoch.keys(): " & e.msg)

    #Make sure the Transaction was verified.
    if weight < ((state.unlocked div 2) + 1):
      continue

    #If it was, increment every verifier's score.
    try:
      for holder in epoch[tx]:
        if not scores.hasKey(holder):
          scores[holder] = 0
        scores[holder] += 1
    except KeyError as e:
      panic("Either couldn't grab the verifiers for an Transaction in the Epoch or the score of a holder: " & e.msg)

  #Make sure at least one Transaction didn't default.
  if scores.len == 0:
    return @[]

  #Multiply every score by how much Merit the holder has.
  for malicious in removed.keys():
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
