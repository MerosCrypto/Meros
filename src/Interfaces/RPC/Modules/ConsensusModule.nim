import sets

import ../../../lib/[Errors, Util, Hash]

import ../../../objects/GlobalFunctionBoxObj

import ../../../Database/Consensus/Consensus

import ../objects/RPCObj

proc module*(
  functions: GlobalFunctionBox
): RPCFunctions {.forceCheck: [].} =
  try:
    newRPCFunctions:
      proc getSendDifficulty(
        holder: Option[uint16] = none(uint16)
      ): int {.forceCheck: [].} =
        if holder.isSome:
          result = functions.consensus.getSendDifficultyOfHolder(holder.unsafeGet())
        else:
          result = functions.consensus.getSendDifficulty()

      proc getDataDifficulty(
        holder: Option[uint16] = none(uint16)
      ): int {.forceCheck: [].} =
        if holder.isSome:
          result = functions.consensus.getDataDifficultyOfHolder(holder.unsafeGet())
        else:
          result = functions.consensus.getDataDifficulty()

      proc getStatus(
        hash: Hash[256]
      ) {.forceCheck: [].} =
        #Get the Status.
        var status: TransactionStatus
        try:
          status = functions.consensus.getStatus(hash)
        except IndexError:
          raise newJSONRPCError(-2, "Transaction Status not found")

        #Get the verifiers and Merit.
        var
          verifiers: JSONNode = % []
          merit: int = max(status.merit, 0)
        for holder in status.holders:
          verifiers.add(% holder)
          if (status.merit == -1) and (not functions.consensus.isMalicious(holder)):
            merit += functions.merit.getMerit(holder, status.epoch)

        res["result"] = %* {
          "verifiers": verifiers,
          "merit":     merit,
          "threshold": functions.consensus.getThreshold(status.epoch),
          "verified":  status.verified,
          "competing": status.competing,
          "beaten":    status.beaten
        }
  except Exception as e:
    panic("Couldn't create the Consensus Module: " & e.msg)
