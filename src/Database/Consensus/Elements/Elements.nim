import macros
import algorithm

import ../../../lib/[Errors, Util, Hash]
import ../../../Wallet/MinerWallet

import objects/[ElementObj, SignedElementObj]
export ElementObj, SignedElementObj

import Verification as VerificationFile
import VerificationPacket as VerificationPacketFile
import SendDifficulty as SendDifficultyFile
import DataDifficulty as DataDifficultyFile
import MeritRemoval as MeritRemovalFile

export VerificationFile, VerificationPacketFile
export SendDifficultyFile, DataDifficultyFile
export MeritRemovalFile

#Enable creating a case statement out of an Element.
#Quality of development life feature.
macro match*(
  e: Element
): untyped =
  result = newTree(nnkIfStmt)

  var
    #Extract the Element symbol.
    symbol: NimNode = e[0]
    branch: NimNode

  #Iterate over every branch in the case.
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
                symbol
              )
            )
          )
        )

        #Add the branch to the returned if statement.
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

    of SendDifficulty as sd1:
      if (
        (not (e2 of SendDifficulty)) or
        (sd1.holder != cast[SendDifficulty](e2).holder) or
        (sd1.nonce != cast[SendDifficulty](e2).nonce) or
        (sd1.difficulty != cast[SendDifficulty](e2).difficulty)
      ):
        return false

    of DataDifficulty as dd1:
      if (
        (not (e2 of DataDifficulty)) or
        (dd1.holder != cast[DataDifficulty](e2).holder) or
        (dd1.nonce != cast[DataDifficulty](e2).nonce) or
        (dd1.difficulty != cast[DataDifficulty](e2).difficulty)
      ):
        return false

    else:
      panic("Unsupported Element type used in equality check.")

proc `!=`*(
  e1: Element,
  e2: Element
): bool {.inline, forceCheck: [].} =
  not (e1 == e2)
