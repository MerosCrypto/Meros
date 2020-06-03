import ../../../../../lib/[Errors, Util]

import ../../../../Transactions/objects/TransactionObj

import ../../../../../Network/Serialize/SerializeCommon

const MINT_OUTPUT_LEN*: int = NICKNAME_LEN + MEROS_LEN

proc parseMintOutput*(
  outputStr: string
): MintOutput {.forceCheck: [].} =
  #Key | Amount
  var outputSeq: seq[string] = outputStr.deserialize(NICKNAME_LEN, MEROS_LEN)

  result = newMintOutput(
    uint16(outputSeq[0].fromBinary()),
    uint64(outputSeq[1].fromBinary())
  )
