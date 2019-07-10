#Element sub-type libs.
import Verification
import MeritRemoval
export Verification
export MeritRemoval

#Signed Element object.
import objects/SignedElementObj
export SIgnedElementObj

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
