import ../../../lib/[Errors, Util, Hash]

import TransactionObj
export TransactionObj

type Data* = ref object of Transaction
  data*: string
  signature*: seq[byte]
  proof*: uint32
  argon*: Hash[256]

func newDataObj*(
  input: Hash[256],
  data: string
): Data {.inline, forceCheck: [].} =
  Data(
    inputs: @[newInput(input)],
    data: data
  )

#Helper function to check if a Data is first.
proc isFirstData*(
  data: Data
): bool {.inline, forceCheck: [].} =
  data.inputs[0].hash == Hash[256]()

#Get the difficulty factor of a specific Data.
proc getDifficultyFactor*(
  data: Data
): uint32 {.inline, forceCheck: [].} =
  (uint32(101) + uint32(data.data.len)) div uint32(102)

#Check if the Data's argon hash overflows against the specified difficulty.
proc overflows*(
  data: Data,
  baseDifficulty: uint32
): bool {.inline, forceCheck: [].} =
  if baseDifficulty == 0:
    return false

  result = Argon(
    data.hash.serialize(),
    data.proof.toBinary(8)
  ).overflows(data.getDifficultyFactor() * baseDifficulty)
