#Errors.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#Element sub-type libs.
import Verification as VerificationFile
import MeritRemoval as MeritRemovalFile
export VerificationFile
export MeritRemovalFile

#Signed Element object.
import objects/SignedElementObj
export SignedElementObj

#Macros standard lib.
import macros

#Custom Element case statement.
macro match*(
    e: Element
): untyped =
    #Create the result.
    result = newTree(nnkIfStmt)

    var
        #Extract the Element symbol.
        symbol: NimNode = e[0]
        #Branch.
        branch: NimNode

    #Iterate over every branch.
    for i in 1 ..< e.len:
        branch = e[i]
        case branch.kind:
            of nnkOfBranch:
                #Verify the syntax.
                if (
                    (branch[0].kind != nnkInfix) or
                    (branch[0].len != 3) or
                    (branch[0][0].strVal != "as")
                ):
                    raise newException(Exception, "Invalid case statement syntax. You must use `of ElementType as castedSymbolName:`")

                #Insert the cast.
                branch[^1].insert(
                    0,
                    newNimNode(nnkVarSection).add(
                        newNimNode(nnkIdentDefs).add(
                            branch[0][2],
                            branch[0][1],
                            newNimNode(nnkCast).add(
                                branch[0][1],
                                newIdentNode(symbol.strVal)
                            )
                        )
                    )
                )

                #Add the branch.
                result.add(
                    newTree(
                        nnkElifBranch,
                        newCall("of", symbol, branch[0][1]),
                        branch[^1]
                    )
                )

            of nnkElse, nnkElseExpr:
                result.add(branch)

            else:
                raise newException(Exception, "Invalid case statement syntax.")

#Element equality operators.
proc `==`*(
    e1: Element,
    e2: Element
): bool {.forceCheck: [].} =
    result = true

    #Test the Element fields.
    if (
        (e1.holder != e2.holder) or
        (e1.nonce != e2.nonce)
    ):
        return false

    #Test the descendant fields.
    case e1:
        of Verification as v1:
            if (
                (not (e2 of Verification)) or
                (v1.hash != cast[Verification](e2).hash)
            ):
                return false

        of MeritRemoval as mr1:
            if (
                (not (e2 of MeritRemoval)) or
                (mr1.partial != cast[MeritRemoval](e2).partial) or
                (not (mr1.element1 == cast[MeritRemoval](e2).element1)) or
                (not (mr1.element2 == cast[MeritRemoval](e2).element2))
            ):
                return false

        else:
            doAssert(false, "Unsupported Element type used in equality check.")

proc `!=`*(
    e1: Element,
    e2: Element
): bool {.inline, forceCheck: [].} =
    not (e1 == e2)
