import strutils
import json

import chronos

import ../../../lib/[Errors, Util, Hash]

import ../../../Wallet/[MinerWallet, Wallet]
import ../../../Wallet/Address as AddressFile

import ../../../Database/Transactions/Transactions

import ../../../Network/Serialize/Transactions/ParseClaim
import ../../../Network/Serialize/Transactions/ParseSend
import ../../../Network/Serialize/Transactions/ParseData

#Used solely when generating work for Transactions about to be published.
import ../../../Network/Serialize/Transactions/SerializeSend
import ../../../Network/Serialize/Transactions/SerializeData

import ../../../objects/GlobalFunctionBoxObj

import ../objects/RPCObj

#Transaction -> JSON.
proc `%`(
  tx: Transaction
): JSONNode {.forceCheck: [].} =
  result = %* {
    "inputs": [],
    "outputs": [],
    "hash": $tx.hash
  }

  try:
    if not (tx of Mint):
      for input in tx.inputs:
        result["inputs"].add(%* {
          "hash": $input.hash
        })

    if not (tx of Data):
      for output in tx.outputs:
        result["outputs"].add(%* {
          "amount": $output.amount
        })
  except KeyError as e:
    panic("Couldn't add inputs/outputs to input/output arrays we just created: " & e.msg)

  case tx:
    of Mint as mint:
      result["descendant"] = % "Mint"

      try:
        for o in 0 ..< result["outputs"].len:
          result["outputs"][o]["nick"] = % cast[MintOutput](mint.outputs[o]).key
      except KeyError as e:
        panic("Couldn't add a Mint's output's key to its output: " & e.msg)

    of Claim as claim:
      result["descendant"] = % "Claim"

      try:
        for i in 0 ..< claim.inputs.len:
          result["inputs"][i]["nonce"] = % cast[FundedInput](claim.inputs[i]).nonce
        for o in 0 ..< claim.outputs.len:
          result["outputs"][o]["key"] = % $cast[SendOutput](claim.outputs[o]).key
      except KeyError as e:
        panic("Couldn't add a Claim's outputs' keys to its outputs: " & e.msg)

      result["signature"] = % $claim.signature

    of Send as send:
      result["descendant"] = % "Send"

      try:
        for i in 0 ..< send.inputs.len:
          result["inputs"][i]["nonce"] = % cast[FundedInput](send.inputs[i]).nonce
        for o in 0 ..< send.outputs.len:
          result["outputs"][o]["key"] = % $cast[SendOutput](send.outputs[o]).key
      except KeyError as e:
        panic("Couldn't add a Send's inputs' nonces/outputs' keys to its inputs/outputs: " & e.msg)

      result["signature"] = % $send.signature
      result["proof"] = % send.proof

    of Data as data:
      result["descendant"] = % "Data"

      result["data"] = % data.data.toHex()

      result["signature"] = % $data.signature
      result["proof"] = % data.proof

proc module*(
  functions: GlobalFunctionBox
): RPCHandle {.forceCheck: [].} =
  try:
    result = newRPCHandle:
      proc getTransaction(
        hash: Hash[256]
      ): JSONNode {.forceCheck: [
        JSONRPCError
      ].} =
        #Get the Transaction.
        try:
          result = % functions.transactions.getTransaction(hash)
        except IndexError:
          raise newJSONRPCError(IndexError, "Transaction not found")

      proc getUTXOs(
        address: Address
      ): JSONNode {.forceCheck: [].} =
        #Get the UTXOs.
        var utxos: seq[FundedInput]
        case address.addyType:
          of AddressType.PublicKey:
            utxos = functions.transactions.getUTXOs(newEdPublicKey(cast[string](address.data)))

        result = % []
        for utxo in utxos:
          result.add(%* {
            "hash": $utxo.hash,
            "nonce": utxo.nonce
          })

      proc getBalance(
        address: Address
      ): string {.forceCheck: [].} =
        #Get the UTXOs.
        var utxos: seq[FundedInput]
        case address.addyType:
          of AddressType.PublicKey:
            utxos = functions.transactions.getUTXOs(newEdPublicKey(cast[string](address.data)))

        var balance: uint64 = 0
        for utxo in utxos:
          try:
            balance += cast[SendOutput](functions.transactions.getTransaction(utxo.hash).outputs[utxo.nonce]).amount
          except IndexError as e:
            panic("Failed to get a Transaction which was a spendable UTXO: " & e.msg)
        result = $balance

      proc publishTransaction(
        type_JSON: string,
        transaction: hex
      ) {.forceCheck: [
        JSONRPCError
      ], async.} =
        try:
          var difficulty: uint32
          case type_JSON:
            of "Claim":
              functions.transactions.addClaim(parseClaim(transaction))
            of "Send":
              difficulty = functions.consensus.getSendDifficulty()
              await functions.transactions.addSend(
                parseSend(transaction, difficulty)
              )
            of "Data":
              difficulty = functions.consensus.getDataDifficulty()
              await functions.transactions.addData(
                parseData(transaction, functions.consensus.getDataDifficulty())
              )
            else:
              raise newJSONRPCError(ValueError, "Invalid Transaction type specified")
        except JSONRPCError as e:
          raise e
        except ValueError as e:
          raise newJSONRPCError(ValueError, "Transaction is invalid: " & e.msg)
        except DataExists:
          return
        except Spam as spam:
          raise newJSONRPCError(Spam, "Transaction didn't beat the spam filter", %* {
            "difficulty": spam.difficulty
          })
        except Exception as e:
          panic("Adding a Transaction raised an Exception despite catching all errors: " & e.msg)

      proc publishTransactionWithoutWork(
        type_JSON: string,
        transaction: hex
      ) {.requireAuth, forceCheck: [
        JSONRPCError
      ], async.} =
        try:
          case type_JSON:
            of "Claim":
              await publishTransaction(type_JSON, transaction)
            of "Send":
              let send: Send = parseSend(transaction & "".pad(4), uint32(0))
              send.mine(uint32(functions.consensus.getSendDifficulty()))
              await publishTransaction(type_JSON, send.serialize())
            of "Data":
              let data: Data = parseData(transaction & "".pad(4), uint32(0))
              data.mine(uint32(functions.consensus.getDataDifficulty()))
              await publishTransaction(type_JSON, data.serialize())
            else:
              raise newJSONRPCError(ValueError, "Invalid Transaction type specified")
        except ValueError as e:
          raise newJSONRPCError(ValueError, "Transaction is invalid: " & e.msg)
        except Spam as e:
          panic("Transaction we're generating work for was labelled Spam: " & e.msg)
        except JSONRPCError as e:
          raise e
        except Exception as e:
          panic("Calling publishTransactionWithoutWork raised an Exception despite catching all errors: " & e.msg)
  except Exception as e:
    panic("Couldn't create the Transactions Module: " & e.msg)
