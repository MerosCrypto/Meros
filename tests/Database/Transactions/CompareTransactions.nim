import tables

import ../../../src/lib/Hash
import ../../../src/Wallet/MinerWallet

import ../../../src/Database/Transactions/Transactions

import ../../Fuzzed

proc compare*(
  i1: Input,
  i2: Input
) =
  check i1.hash == i2.hash
  if i1 is FundedInput:
    check:
      i2 is FundedInput
      cast[FundedInput](i1).nonce == cast[FundedInput](i2).nonce

proc compare*(
  o1: SendOutput or MintOutput,
  o2: SendOutput or MintOutput
) =
  check o1.amount == o2.amount
  check o1.key == o2.key

proc compare*(
  tx1: Transaction,
  tx2: Transaction
) =
  check:
    tx1.inputs.len == tx2.inputs.len
    tx1.outputs.len == tx2.outputs.len
    tx1.hash == tx2.hash

  for i in 0 ..< tx1.inputs.len:
    compare(tx1.inputs[i], tx2.inputs[i])

  case tx1:
    of Mint as _:
      check tx2 of Mint
      for o in 0 ..< tx1.outputs.len:
        compare(cast[MintOutput](tx1.outputs[o]), cast[MintOutput](tx2.outputs[o]))

    of Claim as claim:
      check:
        tx2 of Claim
        claim.signature == cast[Claim](tx2).signature
      for o in 0 ..< tx1.outputs.len:
        compare(cast[SendOutput](tx1.outputs[o]), cast[SendOutput](tx2.outputs[o]))

    of Send as send:
      check:
        tx2 of Send
        send.signature == cast[Send](tx2).signature
        send.proof == cast[Send](tx2).proof
        send.argon == cast[Send](tx2).argon
      for o in 0 ..< tx1.outputs.len:
        compare(cast[SendOutput](tx1.outputs[o]), cast[SendOutput](tx2.outputs[o]))

    of Data as data:
      check:
        tx2 of Data
        data.data == cast[Data](tx2).data
        data.signature == cast[Data](tx2).signature
        data.proof == cast[Data](tx2).proof
        data.argon == cast[Data](tx2).argon

    else:
      check false

proc compare*(
  txs1: Transactions,
  txs2: Transactions
) =
  check txs1.transactions.len == txs2.transactions.len
  for hash in txs1.transactions.keys():
    compare(txs1.transactions[hash], txs2.transactions[hash])
