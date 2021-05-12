import random
import algorithm
import tables

import ../../../../../src/lib/[Util, Hash]
import ../../../../../src/Wallet/Wallet

import ../../../../../src/Database/Filesystem/DB/TransactionsDB

import ../../../../../src/Database/Transactions/objects/TransactionObj
import ../../../../../src/Database/Transactions/Send

import ../../../../Fuzzed
import ../../../TestDatabase

suite "Spendable":
  midFuzzTest "Saving UTXOs, checking which UTXOs an account can spend, and deleting UTXOs.":
    var
      db = newTestDatabase()
      wallets: seq[HDWallet] = @[]

      outputs: seq[SendOutput] = @[]
      send: Send

      #Public Key -> Spendable Outputs.
      spendable: Table[RistrettoPublicKey, seq[FundedInput]] = initTable[RistrettoPublicKey, seq[FundedInput]]()
      inputs: seq[FundedInput] = @[]
      #Loaded Spendable.
      loaded: seq[FundedInput] = @[]
      sends: seq[Send] = @[]
      #Who can spend a FundedInput.
      spenders: Table[string, RistrettoPublicKey] = initTable[string, RistrettoPublicKey]()

    proc inputSort(
      x: FundedInput,
      y: FundedInput
    ): int =
      if x.hash < y.hash:
        result = -1
      elif x.hash > y.hash:
        result = 1
      else:
        if x.nonce < y.nonce:
          result = -1
        elif x.nonce > y.nonce:
          result = 1
        else:
          result = 0

    proc compare() =
      #Test each spendable.
      for key in spendable.keys():
        loaded = db.loadSpendable(key)

        spendable[key].sort(inputSort)
        loaded.sort(inputSort)

        check spendable[key].len == loaded.len
        for i in 0 ..< spendable[key].len:
          check:
            spendable[key][i].hash == loaded[i].hash
            spendable[key][i].nonce == loaded[i].nonce

    #Generate 10 wallets.
    for _ in 0 ..< 10:
      wallets.add(newWallet("").hd)

    #Test 100 Transactions.
    for _ in 0 .. 100:
      outputs = newSeq[SendOutput](rand(254) + 1)
      for o in 0 ..< outputs.len:
        outputs[o] = newSendOutput(
          wallets[rand(10 - 1)].publicKey,
          0
        )

      send = newSend(@[], outputs)
      db.save(send)

      if rand(2) != 0:
        db.verify(send)
        for o in 0 ..< outputs.len:
          if not spendable.hasKey(outputs[o].key):
            spendable[outputs[o].key] = @[]
          spendable[outputs[o].key].add(newFundedInput(send.hash, o))
          spenders[send.hash.serialize() & char(o)] = outputs[o].key

      compare()

      #Spend outputs.
      for key in spendable.keys():
        if spendable[key].len == 0:
          continue

        inputs = @[]
        var i: int = 0
        while i != spendable[key].len:
          if rand(1) == 0:
            inputs.add(spendable[key][i])
            spendable[key].delete(i)
          else:
            inc(i)

        if inputs.len != 0:
          var outputKey: RistrettoPublicKey = wallets[rand(10 - 1)].publicKey
          send = newSend(inputs, newSendOutput(outputKey, 0))
          db.save(send)
          sends.add(send)
          spenders[send.hash.serialize() & char(0)] = outputKey

      compare()

      #Unverify a Send.
      if sends.len != 0:
        var s: int = rand(sends.high)
        db.unverify(sends[s])

        for o1 in 0 ..< sends[s].outputs.len:
          var
            output: SendOutput = cast[SendOutput](sends[s].outputs[o1])
            o2: int = 0
          if spendable.hasKey(output.key):
            while o2 < spendable[output.key].len:
              if (
                (spendable[output.key][o2].hash == sends[s].hash) and
                (spendable[output.key][o2].nonce == o1)
              ):
                spendable[output.key].delete(o2)
              else:
                inc(o2)

        compare()

    #Prune a Send.
    db.prune(sends[sends.high].hash)
    for input in sends[sends.high].inputs:
      if not spendable.hasKey(spenders[input.hash.serialize() & char(cast[FundedInput](input).nonce)]):
        spendable[spenders[input.hash.serialize() & char(cast[FundedInput](input).nonce)]] = @[]
      spendable[
        spenders[input.hash.serialize() & char(cast[FundedInput](input).nonce)]
      ].add(cast[FundedInput](input))

    compare()
