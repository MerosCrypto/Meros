#Errors.
import ../../../lib/Errors

#Hash lib.
import ../../../lib/Hash

#MinerWallet lib.
import ../../../Wallet/MinerWallet

#Element and Signed Element objects.
import objects/ElementObj
import objects/SignedElementObj
export ElementObj
export SignedElementObj

#Element sub-type libs.
import Verification as VerificationFile
import VerificationPacket as VerificationPacketFile
import MeritRemoval as MeritRemovalFile
export VerificationFile
export VerificationPacketFile
export MeritRemovalFile

#Algorithm standard lib.
import algorithm

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

    #If this a BlockElement, test the other is as well and holder.
    if (
        (e1 of BlockElement) and (
            (not (e2 of BlockElement)) or
            (cast[BlockElement](e1).holder != cast[BlockElement](e2).holder)
        )
    ):
        return false

    #Make sure e1 isn't a BlockElement when e2 is.
    if (not (e1 of BlockElement)) and (e2 of BlockElement):
        return false

    #Test the descendant fields.
    case e1:
        of Verification as v1:
            if (
                (not (e2 of Verification)) or
                (v1.holder != cast[Verification](e2).holder) or
                (v1.hash != cast[Verification](e2).hash)
            ):
                return false

        of VerificationPacket as vp1:
            if (
                (not (e2 of VerificationPacket)) or
                (vp1.holders.sorted() != cast[VerificationPacket](e2).holders.sorted()) or
                (vp1.hash != cast[VerificationPacket](e2).hash)
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
