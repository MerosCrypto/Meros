#Errors lib.
import ../../../lib/Errors

#Util lib.
import ../../../lib/Util

#Hash lib.
import ../../../lib/Hash

#Wallet lib.
import ../../../Wallet/Wallet

#Send object.
import ../../../Database/Transactions/objects/SendObj

#Common serialization functions.
import ../SerializeCommon

#Parse function.
proc parseSend*(
    sendStr: string
): Send {.forceCheck: [
    ValueError,
    ArgonError,
    EdPublicKeyError
].} =
    #Verify the input length.
    if sendStr.len < BYTE_LEN:
        raise newException(ValueError, "parseSend not handed enough data to get the amount of inputs.")
    let outputLenPos: int = BYTE_LEN + (int(sendStr[0]) * (HASH_LEN + BYTE_LEN))
    if sendStr.len < outputLenPos + BYTE_LEN:
        raise newException(ValueError, "parseSend not handed enough data to get the amount of outputs.")

    #Inputs Length | Inputs | Outputs Length | Signature | Proof
    var sendSeq: seq[string] = sendStr.deserialize(
        BYTE_LEN,
        sendStr[0].fromBinary() * (HASH_LEN + BYTE_LEN),
        BYTE_LEN,
        sendStr[outputLenPos].fromBinary() * (ED_PUBLIC_KEY_LEN + MEROS_LEN),
        ED_SIGNATURE_LEN,
        INT_LEN
    )

    #Convert the inputs.
    var inputs: seq[SendInput] = newSeq[SendInput](sendSeq[0].fromBinary())
    for i in countup(0, sendSeq[1].len - 1, 49):
        try:
            inputs[i div 49] = newSendInput(sendSeq[1][i ..< i + 48].toHash(384), sendSeq[1][i + 48].fromBinary())
        except ValueError as e:
            fcRaise e

    #Convert the outputs.
    var outputs: seq[SendOutput] = newSeq[SendOutput](sendSeq[2].fromBinary())
    for i in countup(0, sendSeq[3].len - 1, 40):
        try:
            outputs[i div 40] = newSendOutput(newEdPublicKey(sendSeq[3][i ..< i + 32]), uint64(sendSeq[3][i + 32 ..< i + 40].fromBinary()))
        except EdPublicKeyError as e:
            fcRaise e

    #Create the Send.
    result = newSendObj(
        inputs,
        outputs
    )

    #Hash it and set its signature/proof/argon.
    try:
        result.hash = Blake384("\2" & sendSeq[1] & sendSeq[3])
        try:
            result.signature = newEdSignature(sendSeq[4])
        except ValueError as e:
            fcRaise e
        result.proof = sendSeq[5].fromBinary()
        try:
            result.argon = Argon(result.hash.toString(), sendSeq[5], true)
        except ArgonError as e:
            fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when creating a Send: " & e.msg)
