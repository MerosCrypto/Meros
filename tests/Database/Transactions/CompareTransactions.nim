#Fuzzing lib.
import ../../Fuzzed

#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Transactions lib.
import ../../../src/Database/Transactions/Transactions

#Tables lib.
import tables

#Compare two MintOutputs to make sure they have the same value.
proc compare*(
  so1: MintOutput,
  so2: MintOutput
) =
  check(so1.amount == so2.amount)
  check(so1.key == so2.key)

#Compare two SendOutputs to make sure they have the same value.
proc compare*(
  so1: SendOutput,
  so2: SendOutput
) =
  check(so1.amount == so2.amount)
  check(so1.key == so2.key)

#Compare two Transactions to make sure they have the same value.
proc compare*(
  tx1: Transaction,
  tx2: Transaction
) =
  #Test the Transaction fields.
  check(tx1.inputs.len == tx2.inputs.len)
  for i in 0 ..< tx1.inputs.len:
    check(tx1.inputs[i].hash == tx2.inputs[i].hash)
  check(tx1.outputs.len == tx2.outputs.len)
  check(tx1.hash == tx2.hash)

  #Test the sub-type fields.
  case tx1:
    of Mint as _:
      if not (tx2 of Mint):
        check(false)
      for o in 0 ..< tx1.outputs.len:
        compare(cast[MintOutput](tx1.outputs[o]), cast[MintOutput](tx2.outputs[o]))

    of Claim as claim:
      if not (tx2 of Claim):
        check(false)
      for o in 0 ..< tx1.outputs.len:
        compare(cast[SendOutput](tx1.outputs[o]), cast[SendOutput](tx2.outputs[o]))
      check(claim.signature == cast[Claim](tx2).signature)

    of Send as send:
      if not (tx2 of Send):
        check(false)
      for i in 0 ..< tx1.inputs.len:
        check(cast[FundedInput](tx1.inputs[i]).nonce == cast[FundedInput](tx2.inputs[i]).nonce)
      for o in 0 ..< tx1.outputs.len:
        compare(cast[SendOutput](tx1.outputs[o]), cast[SendOutput](tx2.outputs[o]))
      check(send.signature == cast[Send](tx2).signature)
      check(send.proof == cast[Send](tx2).proof)
      check(send.argon == cast[Send](tx2).argon)

    of Data as data:
      if not (tx2 of Data):
        check(false)
      check(data.data == cast[Data](tx2).data)
      check(data.signature == cast[Data](tx2).signature)
      check(data.proof == cast[Data](tx2).proof)
      check(data.argon == cast[Data](tx2).argon)

#Compare two Transactions DAGs to make sure they have the same value.
proc compare*(
  txs1: Transactions,
  txs2: Transactions
) =
  #Test the Transactions and get a list of spent outputs.
  check(txs1.transactions.len == txs2.transactions.len)
  for hash in txs1.transactions.keys():
    compare(txs1.transactions[hash], txs2.transactions[hash])
