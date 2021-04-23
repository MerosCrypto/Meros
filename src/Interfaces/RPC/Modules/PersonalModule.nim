import options
import strutils
import json

import chronos

import ../../../lib/[Errors, Hash, Util]
import ../../../Wallet/[MinerWallet, Wallet]

from ../../../Database/Filesystem/Wallet/WalletDB import KeyIndex, UsableInput

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

      proc setAccount(
        key: EdPublicKey,
        chainCode: Hash[256]
      ) {.requireAuth, forceCheck: [].} =
        functions.personal.setAccount(key, chainCode, true)

      proc getMnemonic(): string {.requireAuth, forceCheck: [
        JSONRPCError
      ].} =
        try:
          result = functions.personal.getMnemonic()
        except ValueError:
          raise newJSONRPCError(ValueError, "Node is running as a WatchWallet and has no Mnemonic")

      proc getMeritHolderKey(): string {.requireAuth, forceCheck: [
        JSONRPCError
      ].} =
        try:
          result = $functions.personal.getMinerWallet().privateKey
        except ValueError:
          raise newJSONRPCError(ValueError, "Node is running as a WatchWallet and has no Merit Holder")

      proc getMeritHolderNick(): uint16 {.requireAuth, forceCheck: [
        JSONRPCError
      ].} =
        try:
          #Not the most optimal path given how the WalletDB tracks the nick.
          result = functions.merit.getNickname(functions.personal.getMinerWallet().publicKey)
        except ValueError:
          raise newJSONRPCError(ValueError, "Node is running as a WatchWallet and has no Merit Holder")
        except IndexError:
          raise newJSONRPCError(IndexError, "Wallet doesn't have a Merit Holder nickname assigned")

      proc getAccount(): JSONNode {.requireAuth, forceCheck: [].} =
        let data: tuple[key: EdPublicKey, chainCode: Hash[256]] = functions.personal.getAccount()
        result = %* {
          "key": $data.key,
          "chainCode": $data.chainCode
        }

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
            "hash": $utxo.utxo.hash,
            "nonce": utxo.utxo.nonce
          })

      proc getTransactionTemplate(
        #outputs_JSON is used to distinguish the name from the below outputs variable, not out of necessity due to using a keyword.
        outputs_JSON: seq[JSONNode],
        from_JSON: Option[seq[string]] = none(seq[string]),
        change: Option[string] = none(string)
      ): JSONNode {.requireAuth, forceCheck: [
        ParamError,
        JSONRPCError
      ].} =
        var
          utxos: seq[UsableInput]
          outputs: seq[SendOutput]
          sum: uint64
          change: uint64

        for output in outputs_JSON:
          try:
            if not (
              (output.kind == JObject) and
              output.hasKey("address") and (output["address"].kind == JString) and
              output.hasKey("amount") and output["amount"].kind == JString
            ):
              raise newLoggedException(ParamError, "Output didn't have address/amount as strings.")

            try:
              var amount: uint64 = 0
              #This should work without issue on x86 systems unless JS is the set target.
              #Removing this dependency means using a BigInt parser here before converting to an uint64.
              #That is feasble with StInt, yet shouldn't be neccessary.
              when not (BiggestUInt is uint64):
                {.error: "Lack of uint64 availability breaks JSON-RPC parsing.".}
              amount = parseBiggestUInt(output["amount"].getStr())
              sum += amount

              let addy: Address = output["address"].getStr().getEncodedData()
              case addy.addyType:
                of AddressType.PublicKey:
                  outputs.add(newSendOutput(newEdPublicKey(cast[string](addy.data)), amount))
            except ValueError:
              raise newJSONRPCError(ValueError, "Invalid address/amount")
          except KeyError as e:
            panic("Couldn't get the key from an output despite screening its fields: " & e.msg)

        #If we're explicitly told which addresses to use, directly call getUTXOs.
        if from_JSON.isSome():
          for addyJSON in from_JSON.unsafeGet():
            var addy: Address
            try:
              addy = addyJSON.getEncodedData()
            except ValueError:
              raise newJSONRPCError(ValueError, "Invalid address to send from")
            case addy.addyType:
              of AddressType.PublicKey:
                let key: EdPublicKey = newEdPublicKey(cast[string](addy.data))
                for utxo in functions.transactions.getUTXOs(key):
                  try:
                    utxos.add(UsableInput(
                      index: functions.personal.getKeyIndex(key),
                      key: key,
                      address: addyJSON,
                      utxo: utxo
                    ))
                  except IndexError:
                    raise newJSONRPCError(IndexError, "Asked to send from unknown address")
        else:
          utxos = functions.personal.getUTXOs()

        #Filter to a minimal UTXO set.
        #Considering it doesn't sort highest amount to lowest, this isn't truly minimal.
        var
          keys: seq[EdPublicKey] = @[]
          u: int = 0
        while u < utxos.len:
          keys.add(utxos[u].key)

          var tx: Transaction
          try:
            tx = functions.transactions.getTransaction(utxos[u].utxo.hash)
          except IndexError as e:
            panic("Couldn't get a Transaction listed as a UTXO: " & e.msg)

          let amount: uint64 = cast[SendOutput](tx.outputs[utxos[u].utxo.nonce]).amount
          if amount >= sum:
            change = amount - sum
            sum = 0
            break
          sum -= amount
          inc(u)
        if sum != 0:
          raise newJSONRPCError(NotEnoughMeros, "Wallet doesn't have enough Meros")
        while (u + 1) != utxos.len:
          utxos.del(u + 1)

        result = %* {
          "type": "Send",
          "inputs": [],
          "outputs": []
        }
        try:
          for input in utxos:
            result["inputs"].add(%* {
              "hash": $input.utxo.hash,
              "nonce": input.utxo.nonce,
              "change": input.index.change,
              "index": input.index.index
            })
          for output in outputs:
            result["outputs"].add(%* {
              "key": $output.key,
              "amount": $output.amount
            })
          if change != 0:
            result["outputs"].add(%* {
              "key": $functions.personal.getChangeKey(),
              "amount": $change
            })
        except KeyError as e:
          panic("Couldn't add an input/output despite ensuring inputs/outputs exist: " & e.msg)
        result["publicKey"] = % $keys.aggregate()

  except Exception as e:
    panic("Couldn't create the Consensus Module: " & e.msg)
