#Errors lib.
import ../../../../../lib/Errors

#Hash lib.
import ../../../../../lib/Hash

#MinerWallet lib.
import ../../../../../Wallet/MinerWallet

#Element lib.
import ../../../../Consensus/Element

#Common serialization functions.
import ../../../../../Network/Serialize/SerializeCommon

#Parse Merit Removal.
import ../../../../../Network/Serialize/Consensus/ParseMeritRemoval

proc parseElement*(
    elem: string,
    key: BLSPublicKey,
    nonce: int
): Element {.forceCheck: [
    ValueError,
    BLSError
].} =
    try:
        case int(elem[0]):
            of VERIFICATION_PREFIX:
                result = newVerificationObj(
                    elem[1 ..< elem.len].toHash(384)
                )
                result.holder = key
                result.nonce = nonce

            of MERIT_REMOVAL_PREFIX:
                result = elem[1 ..< elem.len].parseMeritRemoval()

            else:
                doAssert(false, "Failed to parse an unsupported Element.")
    except ValueError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when loading an Element: " & e.msg)
