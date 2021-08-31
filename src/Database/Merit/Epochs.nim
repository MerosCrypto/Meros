import sets

import ../../lib/[Errors, Hash]

import ../Transactions/objects/[TransactionObj, ClaimObj, DataObj]
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
): HashSet[Hash[256]] {.forceCheck: [].} =
  logDebug "Epochs processing Block", hash = newBlock.header.hash

  var txs: seq[Transaction] = newSeq[Transaction](newBlock.body.packets.len)
  for p in 0 ..< newBlock.body.packets.len:
    try:
      txs[p] = epochs.functions.transactions.getTransaction(newBlock.body.packets[p].hash)
    except IndexError as e:
      panic("Passed a Block verifying non-existent Transactions: " & e.msg)

  var t: int = 0
  while txs.len != 0:
    t = t mod txs.len

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
    if not (txs[t] of Claim):
      for input in txs[t].inputs:
        if (txs[t] of Data) and ((input.hash == Hash[256]()) or (input.hash == epochs.genesis)):
          continue

        try:
          #Check if the parent was finalized.
          #Doesn't use TransactionStatus.finalized as that will consider Transactions which haven't been through Epochs as finalized if beaten.
          if epochs.functions.consensus.getStatus(input.hash).merit == -1:
            #If not present, set canonical to false and break.
            if (not epochs.datas.contains(input.hash)) and (not epochs.currentTXs.contains(input.hash)):
              canonical = false
              break
        except IndexError as e:
          panic("Transaction has non-existent parent: " & e.msg)

    #Since this Transaction is canonical, handle it.
    if canonical:
      epochs.register(txs[t].hash, txs[t].inputs, height)
      txs.del(t)
    #Since this Transaction isn't canonical, move on to the next Transaction.
    else:
      inc(t)

  result = epochs.pop()

#Constructor. Below shift as it calls shift.
proc newEpochs*(
  functions: GlobalFunctionBox,
  blockchain: Blockchain
): Epochs {.forceCheck: [].} =
  #Create the Epochs objects.
  result = newEpochsObj(blockchain.genesis, functions, uint(max(blockchain.height - 15, 0)))

  #Regenerate the Epochs. To do this, we shift the last 15 Blocks (see above formula). Why?
  #The last 5 Blocks are what we actually want, yet we also need the 5 Blocks before that for inputs that were brought up.
  #We also need the 5 Blocks before that to detect when an input first entered Epochs.
  for b in int(result.height) ..< blockchain.height:
    try:
      #This +1 isn't necessary, yet keeps consistency with live behavior.
      discard result.shift(blockchain[b], uint(b + 1))
    except IndexError as e:
      panic("Couldn't shift the last 10 Blocks from the chain: " & e.msg)

proc getPendingTransactions*(
  epochs: Epochs
): HashSet[Hash[256]] {.forceCheck: [].} =
  epochs.currentTXs + epochs.datas
