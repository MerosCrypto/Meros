import deques
import sets, tables

import ../../lib/[Errors, Hash]

import ../Transactions/objects/TransactionObj
import ../Consensus/Elements/objects/VerificationPacketObj
import ../../objects/GlobalFunctionBoxObj

import Block, Blockchain, State

import objects/EpochsObj
export EpochsObj

import Rewards

#This shift does three things:
# - Adds the newest set of Verifications.
# - Stores the oldest Epoch to be returned.
# - Removes the oldest Epoch from Epochs.
proc shift*(
  epochs: Epochs,
  newBlock: Block,
  height: uint
): HashSet[Input] {.forceCheck: [].} =
  logDebug "Epochs processing Block", hash = newBlock.header.hash

  var txs: seq[Transaction] = @[]
  for p in 0 ..< newBlock.body.packets.len:
    try:
      txs[p] = epochs.functions.transactions.getTransaction(newBlock.body.packets[p].hash)
    except IndexError as e:
      panic("Passed a Block verifying non-existent Transactions: " & e.msg)

  var t: int = 0
  while txs.len != 0:
    #The Epochs require Transactions be added with a canonical ordering.
    #Check if this Transaction has all parents already included in Epochs.
    #This is defined as having all parents be either:
    # - Finalized
    # - In Epochs
    #We check the latter property by checking the parents' inputs are all mentioned in Epochs, which is equivalent.
    #If the actual parent has yet to be added, then the worst case is their inputs are in different families.
    #This will be resolved latter in the Block, leaving the dependant status to be the sole item in question.
    #All parent families will have it applied, and it'll be merged when the families are merged, leaving the single in-set instance.
    var canonical: bool = true
    block checkCanonicity:
      for input in txs[t].inputs:
        if (input.hash == Hash[256]()) or (input.hash == epochs.genesis):
          continue

        try:
          #Check if the parent was finalized.
          #Will be true a large portion of the time and is a much cheaper check.
          if epochs.functions.consensus.getStatus(input.hash).merit == -1:
            #If it's not finalized, check presence in Epochs.
            for parentInput in epochs.functions.transactions.getTransaction(input.hash).inputs:
              #If not present, set canonical to false and break.
              if not epochs.inputMap.hasKey(parentInput):
                canonical = false
                break checkCanonicity
        except IndexError as e:
          panic("Transaction has non-existent parent: " & e.msg)

    #Since this Transaction is canonical, handle it.
    if canonical:
      epochs.register(txs[t].inputs, height)
      txs.del(t)
    #Since this Transaction isn't canonical, move on to the next Transaction.
    else:
      t = (t + 1) mod txs.len

  result = epochs.pop()

#Constructor. Below shift as it calls shift.
proc newEpochs*(
  functions: GlobalFunctionBox,
  blockchain: Blockchain
): Epochs {.forceCheck: [].} =
  #Create the Epochs objects.
  result = newEpochsObj(blockchain.genesis, functions, uint(blockchain.height))

  #Regenerate the Epochs. To do this, we shift the last 15 Blocks. Why?
  #The last 5 Blocks are what we actually want, yet we also need the 5 Blocks before that for inputs that were brought up.
  #We also need the 5 Blocks before that to detect when an input first entered Epochs.
  for b in max(blockchain.height - 15, 0) ..< blockchain.height:
    try:
      #This +1 isn't necessary, yet keeps consistency with live behavior.
      #TODO: Test this is actually the case.
      discard result.shift(blockchain[b], uint(b + 1))
    except IndexError as e:
      panic("Couldn't shift the last 10 Blocks from the chain: " & e.msg)
