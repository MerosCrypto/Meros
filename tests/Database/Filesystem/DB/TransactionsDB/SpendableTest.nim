#TransactionsDB Spendable Test.


#Fuzzed lib.
import ../../../../Fuzzed

#Util lib.
import ../../../../../src/lib/Util

#Hash lib.
import ../../../../../src/lib/Hash

#Wallet lib.
import ../../../../../src/Wallet/Wallet

#TransactionDB lib.
import ../../../../../src/Database/Filesystem/DB/TransactionsDB

#Input/Output objects.
import ../../../../../src/Database/Transactions/objects/TransactionObj

#Send lib.
import ../../../../../src/Database/Transactions/Send

#Test Database lib.
import ../../../TestDatabase

#Algorithm standard lib.
import algorithm

#Tables lib.
import tables

#Random standard lib.
import random

suite "Spendable":
    midFuzzTest "Saving UTXOs, checking which UTXOs an account can spend, and deleting UTXOs.":
        var
            #DB.
            db = newTestDatabase()
            #Wallets.
            wallets: seq[Wallet] = @[]

            #Outputs.
            outputs: seq[SendOutput] = @[]
            #Send.
            send: Send

            #Public Key -> Spendable Outputs.
            spendable: Table[EdPublicKey, seq[FundedInput]] = initTable[EdPublicKey, seq[FundedInput]]()
            #Inputs.
            inputs: seq[FundedInput] = @[]
            #Loaded Spendable.
            loaded: seq[FundedInput] = @[]
            #Sends.
            sends: seq[Send] = @[]
            #Who can spend a FundedInput.
            spenders: Table[string, EdPublicKey] = initTable[string, EdPublicKey]()

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

                check(spendable[key].len == loaded.len)
                for i in 0 ..< spendable[key].len:
                    check(spendable[key][i].hash == loaded[i].hash)
                    check(spendable[key][i].nonce == loaded[i].nonce)

        #Generate 10 wallets.
        for _ in 0 ..< 10:
            wallets.add(newWallet(""))

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
                    spenders[send.hash.toString() & char(o)] = outputs[o].key

            compare()

            #Spend outputs.
            var queue: seq[(EdPublicKey, FundedInput)] = @[]
            for key in spendable.keys():
                if spendable[key].len == 0:
                    continue

                inputs = @[]
                var i: int = 0
                while true:
                    if rand(1) == 0:
                        inputs.add(spendable[key][i])
                        spendable[key].delete(i)
                    else:
                        inc(i)

                    if i == spendable[key].len:
                        break

                if inputs.len != 0:
                    var outputKey: EdPublicKey = wallets[rand(10 - 1)].publicKey
                    send = newSend(inputs, newSendOutput(outputKey, 0))
                    db.save(send)
                    db.verify(send)
                    sends.add(send)

                    queue.add((outputKey, newFundedInput(send.hash, 0)))
                    spenders[send.hash.toString() & char(0)] = outputKey

            for output in queue:
                if not spendable.hasKey(output[0]):
                    spendable[output[0]] = @[]
                spendable[output[0]].add(output[1])

            compare()

            #Unverify a Send.
            if sends.len != 0:
                var s: int = rand(sends.high)
                db.unverify(sends[s])
                for input in sends[s].inputs:
                    spendable[
                        spenders[input.hash.toString() & char(cast[FundedInput](input).nonce)]
                    ].add(cast[FundedInput](input))

                for o1 in 0 ..< sends[s].outputs.len:
                    var output: SendOutput = cast[SendOutput](sends[s].outputs[o1])
                    for o2 in 0 ..< spendable[output.key].len:
                        if (
                            (spendable[output.key][o2].hash == sends[s].hash) and
                            (spendable[output.key][o2].nonce == o1)
                        ):
                            spendable[output.key].delete(o2)
                            break

            compare()
