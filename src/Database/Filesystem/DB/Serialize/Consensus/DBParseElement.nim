#Errors lib.
import ../../../../../lib/Errors

#Hash lib.
import ../../../../../lib/Hash

#MinerWallet lib.
import ../../../../../Wallet/MinerWallet

#Verification object.
import ../../../../Consensus/Elements/objects/VerificationObj

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Parse Merit Removal.
import ../../../../../Network/Serialize/Consensus/ParseMeritRemoval

proc parseElement*(
    elem: string,
    nick: uint32
): Element {.forceCheck: [
    ValueError
].} =
    try:
        case int(elem[0]):
            of VERIFICATION_PREFIX:
                discard

            of MERIT_REMOVAL_PREFIX:
                discard

            else:
                doAssert(false, "Failed to parse an unsupported Element.")
    except ValueError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when loading an Element: " & e.msg)
