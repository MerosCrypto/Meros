#Errors lib.
import ../../../../../lib/Errors

#Util lib.
import ../../../../../lib/Util

#Hash lib.
import ../../../../../lib/Hash

#Mint object.
import ../../../..//Transactions/objects/MintObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Parse function.
proc parseMint*(
    mintStr: string
): Mint {.forceCheck: [].} =
    #Nonce | Recepient | Meros
    var mintSeq: seq[string] = mintStr.deserialize(
        INT_LEN,
        NICKNAME_LEN,
        MEROS_LEN
    )

    #Create the Mint.
    result = newMintObj(
        uint32(mintSeq[0].fromBinary()),
        uint16(mintSeq[1].fromBinary()),
        uint64(mintSeq[2].fromBinary())
    )

    #Hash it.
    try:
        result.hash = Blake384("\0" & mintStr)
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when parsing a Mint: " & e.msg)
