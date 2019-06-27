#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#MinerWallet lib.
import ../../../../../Wallet/MinerWallet

#MintOutput object.
import ../../../..//Transactions/objects/TransactionObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Parse function.
proc parseMintOutput*(
    outputStr: string
): MintOutput {.forceCheck: [
    BLSError
].} =
    #Key | Amount
    var outputSeq: seq[string] = outputStr.deserialize(
        BLS_PUBLIC_KEY_LEN,
        MEROS_LEN
    )

    #Create the MintOutput.
    try:
        result = newMintOutput(
            newBLSPublicKey(outputSeq[0]),
            uint64(outputSeq[1].fromBinary())
        )
    except BLSError as e:
        fcRaise e
