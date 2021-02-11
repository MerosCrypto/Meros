import options
import parseutils
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

      proc setParentPublicKey(
        account: uint32 = 0,
        key: EdPublicKey
      ) {.requireAuth, forceCheck: [
        JSONRPCError
      ].} =
        raise newJSONRPCError(ValueError, "personal_setParentPublicKey isn't implemented")

      proc getMnemonic(): string {.requireAuth, forceCheck: [].} =
        functions.personal.getWallet().mnemonic.sentence

      proc getMeritHolderKey(): string {.requireAuth, forceCheck: [].} =
        $functions.personal.getMinerWallet().publicKey

      proc getParentPublicKey(
        account: uint32 = 0,
        password: string = ""
      ): string {.requireAuth, forceCheck: [
        JSONRPCError
      ].} =
        raise newJSONRPCError(ValueError, "personal_getParentPublicKey isn't implemented")

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

      proc send(
        account: uint32,
        outputs: JSONNode,
        password: string
      ): string {.requireAuth, forceCheck: [
        ParamError,
        JSONRPCError
      ].} =
        if outputs.kind != JArray:
          raise newException(ParamError, "Outputs weren't in an array")

        var outputSeq: seq[tuple[address: Address, amount: uint64]] = @[]
        for output in outputs:
          try:
            if not (
              (output.kind == JObject) and
              (output.len == 2) and
              output.hasKey("address") and (output["address"].kind == JString) and
              output.hasKey("amount") and (output["amount"].kind == JString)
            ):
              raise newException(ParamError, "An output wasn't a properly structured object")
          except KeyError as e:
            panic("Couldn't check the type of a field despite guaranteeing its existence: " & e.msg)

          try:
            outputSeq.add((address: output["address"].getStr().getEncodedData(), amount: uint64(0)))
            #No idea how this behaves on x86 platforms.
            #A runtime parse/serialize check would work, yet it'd only support fractional Meros values in an int32.
            #That makes this the only feasible option, for now.
            #-- Kayaba
            when not (BiggestUInt is uint64):
              {.error: "Lack of uint64 availability breaks JSON-RPC parsing.".}
            #Returned value is amount of parsed characters; not relevant to us nor worth the length check.
            #This will error on overflow.
            discard parseBiggestUInt(output["amount"].getStr(), outputSeq[^1].amount)
          except KeyError as e:
            panic("Couldn't get a field despite guaranteeing its existence: " & e.msg)
          except ValueError as e:
            raise newJSONRPCError(ValueError, "Invalid address or amount: " & e.msg)

        raise newJSONRPCError(ValueError, "personal_send isn't implemented")

      proc data(
        account: uint32,
        hex: bool,
        data: string,
        password: string = ""
      ) {.requireAuth, forceCheck: [
        JSONRPCError
      ].} =
        raise newJSONRPCError(ValueError, "personal_data isn't implemented")

      proc getUTXOs(
        account: uint32
      ): JSONNode {.requireAuth, forceCheck: [
        JSONRPCError
      ].} =
        raise newJSONRPCError(ValueError, "personal_getUTXOs isn't implemented")

      proc getTransactionTemplate(
        amount: string,
        destination: string,
        account: Option[uint32] = none(uint32),
        from_JSON: Option[seq[string]] = none(seq[string]),
        change: Option[string] = none(string)
      ): JSONNode {.requireAuth, forceCheck: [
        ParamError,
        JSONRPCError
      ].} =
        if account.isSome() and from_JSON.isSome():
          raise newLoggedException(ParamError, "personal_getUTXOs had both account and from set")
        raise newJSONRPCError(ValueError, "personal_getUTXOs isn't implemented")
  except Exception as e:
    panic("Couldn't create the Consensus Module: " & e.msg)
