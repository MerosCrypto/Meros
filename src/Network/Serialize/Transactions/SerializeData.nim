import ../../../lib/[Errors, Hash]

import ../../../Database/Transactions/objects/DataObj

import ../SerializeCommon

import SerializeTransaction
export SerializeTransaction

method serializeHash*(
  data: Data
): string {.inline, forceCheck: [].} =
  "\3" &
  data.inputs[0].hash.serialize() &
  data.data

method serialize*(
  data: Data
): string {.inline, forceCheck: [].} =
  data.inputs[0].hash.serialize() &
  char(data.data.len - 1) &
  data.data &
  cast[string](data.signature) &
  data.proof.toBinary(INT_LEN)
