#Transactions sub-type libs.
import Mint
import Claim
import Send
import Data

export Mint
export Claim
export Send
export Data

#Macros standard lib.
import macros

#Custom Element case statement.
macro match*(
    tx: Transaction
): untyped =
    #Create the result.
    result = newTree(nnkIfStmt)

    var
        #Extract the Element symbol.
        symbol: NimNode = tx[0]
        #Branch.
        branch: NimNode
        #Covers every Transaction type.
        hasElse: bool = false

    #Iterate over every branch.
    for i in 1 ..< tx.len:
        branch = tx[i]
        case branch.kind:
            of nnkOfBranch:
                #Verify the syntax.
                if (
                    (branch[0].kind != nnkInfix) or
                    (branch[0].len != 3) or
                    (branch[0][0].strVal != "as")
                ):
                    raise newException(Exception, "Invalid case statement syntax. You must use `of TransactionType as castedSymbolName:`")

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
                hasElse = true
                result.add(branch)

            else:
                raise newException(Exception, "Invalid case statement syntax.")

    #Make sure all cases are covered.
    if not hasElse:
        if result.len != 4:
            raise newException(Exception, "Not all Transaction types were covered.")
