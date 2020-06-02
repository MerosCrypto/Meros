#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#MintOutput object.
import ../../../../Transactions/objects/TransactionObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Mint output length.
const MINT_OUTPUT_LEN*: int = NICKNAME_LEN + MEROS_LEN

#Parse function.
proc parseMintOutput*(
  outputStr: string
): MintOutput {.forceCheck: [].} =
  #Key | Amount
  var outputSeq: seq[string] = outputStr.deserialize(
    NICKNAME_LEN,
    MEROS_LEN
  )

  #Create the MintOutput.
  result = newMintOutput(
    uint16(outputSeq[0].fromBinary()),
    uint64(outputSeq[1].fromBinary())
  )
