import sets, tables

import ../../../../../lib/[Errors, Util]
import ../../../../../Wallet/MinerWallet

import ../../../../Consensus/objects/TransactionStatusObj

import ../../../../../Network/Serialize/SerializeCommon

proc serialize*(
  status: TransactionStatus
): string {.forceCheck: [].} =
  result =
    status.epoch.toBinary(INT_LEN) &
    char(status.merit != -1) &
    char(status.competing) &
    char(status.verified) &
    char(status.beaten) &
    status.holders.len.toBinary(NICKNAME_LEN)

  try:
    for holder in status.holders:
      result &= holder.toBinary(NICKNAME_LEN)
      if (status.merit == -1) and status.signatures.hasKey(holder):
        result &= char(true)
        result &= status.signatures[holder].serialize()
      else:
        result &= char(false)
  except KeyError as e:
    panic("Couldn't get the signature of a holder who has a signature in a pending TransactionStatus: " & e.msg)

  if status.merit == -1:
    result &= status.packet.holders.len.toBinary(NICKNAME_LEN)
    for holder in status.packet.holders:
      result &= holder.toBinary(NICKNAME_LEN)
  else:
    result &= status.merit.toBinary(NICKNAME_LEN)
