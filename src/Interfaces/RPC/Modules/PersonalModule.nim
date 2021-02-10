import options
import json

import chronos

import ../../../lib/[Errors, Util]
import ../../../Wallet/[MinerWallet, Wallet]

import ../../../objects/GlobalFunctionBoxObj

import ../objects/RPCObj

proc module*(
  functions: GlobalFunctionBox
): RPCHandle {.forceCheck: [].} =
  try:
    result = newRPCHandle:
      proc setMnemonic(
        mnemonic: Option[string] = some(""),
        password: string = ""
      ) {.requireAuth, forceCheck: [
        JSONRPCError
      ].} =
        try:
          functions.personal.setMnemonic(mnemonic.unsafeGet(), password)
        except ValueError:
          raise newJSONRPCError(ValueError, "Invalid mnemonic")

      #[proc setParentPublicKey(
        account: uint32,
        key: EdPublicKey
      ) {.requireAuth, forceCheck: [].} =
        raise newJSONRPCError(ValueError, "setParentPublicKey isn't implemented")]#

      proc getMnemonic(): string {.requireAuth, forceCheck: [].} =
        functions.personal.getWallet().mnemonic.sentence

      proc getMeritHolderKey(): string {.requireAuth, forceCheck: [].} =
        $functions.personal.getMinerWallet().publicKey

      proc getAddress(
        account: Option[uint32] = some(uint32(0)),
        change: Option[bool] = some(false),
        index: Option[uint32] = none(uint32),
        password: Option[string] = some("")
      ): string {.requireAuth, forceCheck: [
        JSONRPCError
      ].} =
        #Get the account in question.
        var wallet: HDWallet = functions.personal.getWallet()
        try:
          wallet = wallet[account.unsafeGet()]
        except ValueError:
          raise newJSONRPCError(ValueError, "Unusable account")

        #Get the tree in question.
        try:
          wallet = wallet.derive(if change.unsafeGet(): 1 else: 0)
        except ValueError as e:
          panic("Unusable external/internal trees despite checking for their validity: " & e.msg)

        #Get the child.
        if index.isNone():
          try:
            result = wallet.next().address
          except ValueError:
            raise newJSONRPCError(ValueError, "Tree has no valid children remaining")
        else:
          try:
            result = wallet[index.unsafeGet()].address
          except ValueError:
            raise newJSONRPCError(ValueError, "Index isn't viable")

      #[proc send(
      ) {.requireAuth, forceCheck: [
        ParamError,
        JSONRPCError
      ], async.} =
        #Verify the params.
        if (
          (params.len != 2) or
          (params[0].kind != JString) or
          (params[1].kind != JString)
        ):
          raise newException(ParamError, "")

        try:
          res["result"] = % $(await functions.personal.send(params[0].getStr(), params[1].getStr()))
        except ValueError:
          raise newJSONRPCError(-3, "Invalid address/amount")
        except NotEnoughMeros:
          raise newJSONRPCError(1, "Not enough Meros")
        except Exception as e:
          panic("send threw an Exception despite catching everything: " & e.msg)

      proc data(
      ) {.requireAuth, forceCheck: [
        ParamError,
        JSONRPCError
      ], async.} =
        #Verify the params.
        if (
          (params.len != 1) or
          (params[0].kind != JString)
        ):
          raise newException(ParamError, "")

        try:
          res["result"] = % $(await functions.personal.data(params[0].getStr()))
        except ValueError:
          raise newJSONRPCError(-3, "Invalid data length")
        except Exception as e:
          panic("send threw an Exception despite catching everything: " & e.msg)]#
  except Exception as e:
    panic("Couldn't create the Consensus Module: " & e.msg)
