import options
import strutils
import json

import chronos

import ../../../lib/[Errors, Hash, Util]
import ../../../Wallet/[MinerWallet, Wallet]
import ../../../Database/Transactions/Send

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
        key: RistrettoPublicKey,
        chainCode: Hash[256]
      ) {.requireAuth, forceCheck: [].} =
        functions.personal.setAccount(key, chainCode, true)

      proc getMnemonic(): string {.requireAuth, forceCheck: [
        JSONRPCError
      ].} =
        try:
          result = functions.personal.getMnemonic()
        except ValueError as e:
          raise newJSONRPCError(ValueError, e.msg)

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
        let data: tuple[key: RistrettoPublicKey, chainCode: Hash[256]] = functions.personal.getAccount()
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

      proc data(
        hex: bool = false,
        data_JSON: string,
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
        #_JSON is used to distinguish the name from the below variables, not out of necessity due to using a keyword.
        outputs_JSON: seq[JSONNode],
        from_JSON: Option[seq[string]] = none(seq[string]),
        change_JSON: Option[string] = none(string)
      ): JSONNode {.requireAuth, forceCheck: [
        ParamError,
        JSONRPCError
      ].} =
        if outputs_JSON.len == 0:
          raise newJSONRPCError(ValueError, "No outputs were provided")

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
              raise newLoggedException(ParamError, "Output didn't have address/amount as strings")

            try:
              var amount: uint64 = 0
              #This should work without issue on x86 systems unless JS is the set target.
              #Removing this dependency means using a BigInt parser here before converting to an uint64.
              #That is feasble with StInt, yet shouldn't be neccessary.
              when not (BiggestUInt is uint64):
                {.error: "Lack of uint64 availability breaks JSON-RPC parsing.".}
              amount = parseBiggestUInt(output["amount"].getStr())
              if amount == 0:
                raise newJSONRPCError(ValueError, "0 value output was provided")
              if $amount != output["amount"].getStr():
                raise newJSONRPCError(ValueError, "Amount exceeded the uint64 range and is not a valid Meros amount")
              sum += amount

              let addy: Address = output["address"].getStr().getEncodedData()
              case addy.addyType:
                of AddressType.PublicKey:
                  outputs.add(newSendOutput(newRistrettoPublicKey(cast[string](addy.data)), amount))
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
                let key: RistrettoPublicKey = newRistrettoPublicKey(cast[string](addy.data))
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
          keys: seq[RistrettoPublicKey] = @[]
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
            if change_JSON.isSome():
              try:
                let addy: Address = change_JSON.unsafeGet().getEncodedData()
                case addy.addyType:
                  of AddressType.PublicKey:
                    result["outputs"].add(%* {
                      "key": $newRistrettoPublicKey(cast[string](addy.data)),
                      "amount": $change
                    })
              except ValueError:
                raise newJSONRPCError(ValueError, "Invalid change address specified")
            else:
              result["outputs"].add(%* {
                "key": $functions.personal.getChangeKey(),
                "amount": $change
              })
        except KeyError as e:
          panic("Couldn't add an input/output despite ensuring inputs/outputs exist: " & e.msg)
        result["publicKey"] = % $keys.aggregate()

      proc send(
        outputs_JSON: seq[JSONNode],
        password: Option[string] = none(string)
      ): Future[string] {.requireAuth, forceCheck: [
        ParamError,
        JSONRPCError
      ], async.} =
        #Outsource to getTransactionTemplate which already implements all this logic.
        var txTemplate: JSONNode
        try:
          txTemplate = getTransactionTemplate(outputs_JSON, none(seq[string]), none(string))
        except ParamError as e:
          raise e
        except JSONRPCError as e:
          raise e

        var
          inputs: seq[FundedInput] = @[]
          keys: seq[KeyIndex] = @[]
          outputs: seq[SendOutput] = @[]
          send: Send
        try:
          for input in txTemplate["inputs"]:
            inputs.add(newFundedInput(input["hash"].getStr().parseHexStr().toHash[:256](), input["nonce"].getInt()))
            keys.add(KeyIndex(
              change: input["change"].getBool(),
              index: uint32(input["index"].getInt())
            ))
          for output in txTemplate["outputs"]:
            #There's a note above about the use of parseBiggestUInt which applies here as well.
            outputs.add(newSendOutput(newRistrettoPublicKey(parseHexStr(output["key"].getStr())), parseBiggestUInt(output["amount"].getStr())))
        except KeyError, ValueError:
          panic("personal_send failed due to personal_getTransactionTemplate not returning a valid template.")
        send = newSend(inputs, outputs)

        #Create the proper object and call sign.
        try:
          functions.personal.sign(send, keys, password.get(""))
        except IndexError as e:
          panic("Tried to sign a template with an unusable key: " & e.msg)
        except ValueError as e:
          raise newJSONRPCError(ValueError, e.msg)

        #Mine it.
        send.mine(functions.consensus.getSendDifficulty())

        #Add it.
        try:
          await functions.transactions.addSend(send)
        except ValueError as e:
          panic("Created an invalid Send in personal_send: " & e.msg)
        #This should be impossible since we use chronos.
        #It wouldn't be impossible if we used the stdlib's async (or at least, old versions of it).
        #Because we use chronos, Futures should be handled FIFO, meaning although the above loses flow control...
        #Another personal_getUTXOs requestt couldn't snipe UTXOs from it.
        #That leaves two nodes issuing this command at the same time, which sould also be impossible.
        #This is because it's a single call to await at the end of the function.
        #We don't have a good way to continue if this error did ever pop up anyways...
        #Except possibly just trying the TX again with new UTXOs? Anyways. Just panic.
        except DataExists as e:
          panic("Created a Send that exists: " & e.msg)
        except Exception as e:
          panic("addSend threw an Exception despite catching all errors: " & e.msg)

        result = $send.hash

  except Exception as e:
    panic("Couldn't create the Consensus Module: " & e.msg)
