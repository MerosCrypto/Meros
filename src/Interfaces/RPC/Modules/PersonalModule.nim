import options
import json

import chronos

import ../../../lib/[Errors, Hash, Util]
import ../../../Wallet/[MinerWallet, Wallet]

import ../../../objects/GlobalFunctionBoxObj

import ../objects/RPCObj

proc module*(
  functions: GlobalFunctionBox
): RPCHandle {.forceCheck: [].} =
  try:
    result = newRPCHandle:
      proc setWallet(
        mnemonic: Option[string] = some(""),
        password: string = ""
      ) {.requireAuth, forceCheck: [
        JSONRPCError
      ].} =
        try:
          functions.personal.setWallet(mnemonic.unsafeGet(), password)
        except ValueError:
          raise newJSONRPCError(ValueError, "Invalid mnemonic or password")

      proc setAccountKey(
        account: uint32 = 0,
        key: EdPublicKey
      ) {.requireAuth, forceCheck: [
        JSONRPCError
      ].} =
        raise newJSONRPCError(ValueError, "personal_setAccountKey isn't implemented")

      proc getMnemonic(): string {.requireAuth, forceCheck: [].} =
        functions.personal.getMnemonic()

      proc getMeritHolderKey(): string {.requireAuth, forceCheck: [].} =
        $functions.personal.getMinerWallet().privateKey

      proc getMeritHolderNick(): uint16 {.requireAuth, forceCheck: [
        JSONRPCError
      ].} =
        try:
          #Not the most optimal path given how the WalletDB tracks the nick.
          result = functions.merit.getNickname(functions.personal.getMinerWallet().publicKey)
        except IndexError:
          raise newJSONRPCError(IndexError, "Wallet doesn't have a Merit Holder nickname assigned")

      proc getAccountKey(): string {.requireAuth, forceCheck: [].} =
        $functions.personal.getAccountKey()

      proc getAddress(
        index: Option[uint32] = none(uint32)
      ): string {.requireAuth, forceCheck: [
        JSONRPCError
      ].} =
        if index.isSome() and (index.unsafeGet() >= (1 shl 31)):
          raise newJSONRPCError(ValueError, "Hardened index specified")
        try:
          result = functions.personal.getAddress(index)
        except ValueError:
          raise newJSONRPCError(ValueError, "Invalid index")

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
        data_JSON: string,
        hex: bool = false,
        password: string = ""
      ): Future[string] {.requireAuth, forceCheck: [
        JSONRPCError
      ], async.} =
        var data: string = data_JSON
        if hex:
          try:
            data = parseHexStr(data)
          except ValueError as e:
            raise newJSONRPCError(ValueError, e.msg)

        try:
          result = $(await functions.personal.data(data, password))
        except ValueError as e:
          raise newJSONRPCError(ValueError, e.msg)
        except Exception as e:
          panic("personal.data threw an Exception despite catching all Exceptions: " & e.msg)

      proc getUTXOs(): JSONNode {.requireAuth, forceCheck: [].} =
        result = % []
        for utxo in functions.personal.getUTXOs():
          result.add(%* {
            "address": utxo.address,
            "hash": $utxo.hash,
            "nonce": utxo.nonce
          })

      proc getTransactionTemplate(
        outputs: seq[JSONNode],
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
