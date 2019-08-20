#Errors lib.
import ../../lib/Errors

#Hash lib.
import ../../lib/Hash

#Wallet libs.
import ../../Wallet/Wallet
import ../../Wallet/MinerWallet

#Consensus lib.
import ../Consensus/Consensus

#Merit lib.
import ../Merit/Merit

#Transactions DB lib.
import ../Filesystem/DB/TransactionsDB

#MeritHolderRecord object.
import ../common/objects/MeritHolderRecordObj

#Difficulties object.
import objects/DifficultiesObj
export DifficultiesObj

#Transaction lib.
import Transaction
export Transaction

#Transactions object.
import objects/TransactionsObj
export TransactionsObj.Transactions, `[]`
export getUTXOs, toString
export loadData

#Seq utils standard lib.
import sequtils

#Tables standard lib.
import tables

#Helper function to check if a Data's inputs are valid, and if so, return the sender.
proc getSender*(
    transactions: Transactions,
    data: Data
): EdPublicKey {.forceCheck: [
    ValueError
].} =
    try:
        result = transactions.loadSender(data.inputs[0].hash)
    except DBReadError:
        for b in 0 ..< 16:
            if data.inputs[0].hash.data[b] != 0:
                raise newException(ValueError, "Data's input is a Data we don't have or already used as an input.")

        for b in 16 ..< 48:
            result.data[b - 16] = cuchar(data.inputs[0].hash.data[b])

#Add a Verification to the weights table.
proc verify*(
    transactions: var Transactions,
    verif: Verification,
    merit: int,
    liveMerit: int,
    save: bool = true
) {.forceCheck: [
    ValueError
].} =
    #Turn the hash into a string.
    var hash: string = verif.hash.toString()

    #Verify the Transaction exists.
    if not transactions.transactions.hasKey(hash):
        raise newException(ValueError, "Transaction either doesn't exist or is already out of the Epochs.")

    #Add the Verification.
    var weight: int
    try:
        transactions.weights[hash] += merit
        #Save the weight so we can use it in the future without a potential KeyError.
        weight = transactions.weights[hash]
    except KeyError as e:
        doAssert(false, "Couldn't get a Transaction's weight despite guaranteeing it had a weight: " & e.msg)

    #Grab the Transaction.
    var tx: Transaction
    try:
        tx = transactions.transactions[hash]
    except KeyError:
        doAssert(false, "Couldn't get a Transaction despite confirming it's in the cache.")

    #Now that the Transaction has one Verification and can be defaulted, update spent.
    if not (
        (tx of Data) and
        (cast[Data](tx).isFirstData)
    ):
        var inputStr: string
        for input in tx.inputs:
            inputStr = input.toString(tx)

            #If a previous TX marked this input as spent, don't overwrite it.
            if transactions.spent.hasKey(inputStr):
                continue

            transactions.spent[inputStr] = tx.hash

    #If the Transaction has at least 50.1% of the weight...
    #(+600 for the Meros minted while a Transaction can be verified)
    if weight > (liveMerit div 2) + 600:
        #If the Transaction was already verified, return.
        if tx.verified:
            return

        #Guarantee all spent UTXOs are still available.
        if not save:
            for input in tx.inputs:
                case tx:
                    of Mint as _:
                        discard

                    of Claim as _:
                        try:
                            discard transactions.loadUTXO(input.hash)
                        except DBreadError:
                            doAssert(false, "Verified Claim spends no longer spendable Mints.")

                    of Send as _:
                        try:
                            discard transactions.loadUTXO(cast[SendInput](input))
                        except DBreadError:
                            doAssert(false, "Verified Send spends no longer spendable UTXOs.")

                    of Data as _:
                        discard

            if tx of Data:
                var hasData: bool
                try:
                    discard transactions.loadData(transactions.getSender(cast[Data](tx)))
                    hasData = true
                except DBReadError:
                    hasData = false
                except ValueError:
                    doAssert(false, "Verified Data 'spends' an unknown/spent Data.")

                if cast[Data](tx).isFirstData and hasData:
                    doAssert(false, "Verified Data is 'first' yet a competing 'first' Data is already verified.")

        #Set it to verified.
        tx.verified = true

        #If we're not just reloading Verifications, and should update UTXOs...
        if save:
            echo tx.hash, " was verified."
            transactions.verify(tx.hash)

            #Mark spent UTXOs as spent and create new UTXOs.
            case tx:
                of Mint as _:
                    discard

                of Claim as _:
                    #Up to 255 Mint UTXOs spent.
                    for input in tx.inputs:
                        transactions.spend(input.hash)
                    #Svae the output.
                    transactions.saveUTXOs(tx.hash, cast[seq[SendOutput]](tx.outputs))

                of Send as _:
                    #Up to 255 Send UTXOs spent.
                    for input in tx.inputs:
                        transactions.spend(cast[SendInput](input))
                    #Svae the outputs.
                    transactions.saveUTXOs(tx.hash, cast[seq[SendOutput]](tx.outputs))

                of Data as data:
                    #Save this as the tip data.
                    var sender: EdPublicKey
                    try:
                        sender = transactions.getSender(data)
                    except ValueError as e:
                        doAssert(false, "Couldn't get the sender of an added Data: " & e.msg)
                    transactions.saveData(sender, data.hash)

#Remove a Verification.
proc unverify*(
    transactions: var Transactions,
    verif: Verification,
    merit: int,
    liveMerit: int
) {.forceCheck: [
    ValueError
].} =
    #Turn the hash into a string.
    var hash: string = verif.hash.toString()

    #Verify the Transaction exists.
    if not transactions.transactions.hasKey(hash):
        raise newException(ValueError, "Transaction either doesn't exist or is already out of the Epochs.")

    #Remove the Verification from the weight.
    var weight: int
    try:
        transactions.weights[hash] -= merit
        #Save the weight so we can use it in the future without a potential KeyError.
        weight = transactions.weights[hash]
    except KeyError as e:
        doAssert(false, "Couldn't get a Transaction's weight despite guaranteeing it had a weight: " & e.msg)

    #Grab the Transaction.
    var tx: Transaction
    try:
        tx = transactions.transactions[hash]
    except KeyError:
        doAssert(false, "Couldn't get a Transaction despite confirming it's in the cache.")

    if (tx.verified) and (weight <= (liveMerit div 2) + 600):
        tx.verified = false
        doAssert(false, $tx.hash & " WAS REVERTED!")

#Constructor.
proc newTransactions*(
    db: DB,
    consensus: Consensus,
    merit: Merit,
    sendDiff: string,
    dataDiff: string
): Transactions {.forceCheck: [].} =
    #Create the Transactions.
    result = newTransactionsObj(
        db,
        consensus,
        merit,
        sendDiff,
        dataDiff
    )

    #Reload the Verifications.

    #Grab every MeritHolder mentioned in the last 6 Blocks of Elements.
    var mentioned: Table[string, BLSPublicKey] = initTable[string, BLSPublicKey]()
    try:
        for nonce in max(0, merit.blockchain.height - 5) ..< merit.blockchain.height:
            for record in merit.blockchain[nonce].records:
                mentioned[record.key.toString()] = record.key
    except IndexError as e:
        doAssert(false, "Couldn't load records from the Blockchain while reloading Transactions: " & e.msg)

    if mentioned.len == 0:
        return

    #Create a seq of States.
    var states: seq[State] = newSeq[State](
        min(merit.blockchain.height - 1, 6) + 1
    )

    #Copy the State for reverting.
    var reverted: State = merit.state
    #Fill the States seq with the historicval States.
    for s in countdown(states.len - 1, 0):
        states[s] = reverted
        reverted.revert(merit.blockchain, reverted.processedBlocks - 1)

    #Iterate over every MeritHolder.
    for holderStr in mentioned.keys():
        var
            #Holder as a BLSPublicKey.
            holder: BLSPublicKey
            #Define the tips,
            tips: seq[int] = newSeq[int](1)
        #Extract the holder.
        try:
            holder = mentioned[holderStr]
        except KeyError:
            doAssert(false, "Couldn't get a value by a key produced from .keys().")

        #Grab their out-of-epoch tip.
        try:
            tips[0] = result.load(holder)
        except DBReadError:
            tips[0] = -2

        #Grab their tips in the Blocks.
        for b in max(merit.blockchain.height - 6, 1) ..< merit.blockchain.height:
            var tip: int = -1
            try:
                for record in merit.blockchain[b].records:
                    if record.key == holder:
                        tip = record.nonce
                        break
            except IndexError as e:
                doAssert(false, "Couldn't grab a Block when reloading Transactions' Verifications: " & e.msg)
            tips.add(tip)

        #Add their height to the end.
        tips.add(consensus[holder].height - 1)

        #Iterate over every tip.
        for t in 0 ..< tips.len - 1:
            #If we weren't mentioned in a Block, continue.
            if tips[t] == -1:
                continue

            #If this is the last tip, which is equivalent to the height, continue.
            if (t == tips.len - 2) and (tips[t] == tips[t + 1]):
                continue

            #If we don't have a tip out-of-epochs, change this to an usable value.
            if tips[t] == -2:
                tips[t] = -1

            #Grab the State used at the time.
            var state: State = states[t + 1]

            #Load the Elements archived in this Block.
            var
                nextT: int = t + 1
                nextTip: int = tips[nextT]
            while nextTip == -1:
                inc(nextT)
                nextTip = tips[nextT]

            #Update the State accordingly.
            state = states[nextT - 1]

            for e in tips[t] + 1 .. nextTip:
                var elem: Element
                try:
                    elem = consensus[holder][e]
                except IndexError as e:
                    doAssert(false, "Couldn't grab a Element we know we have: " & e.msg)

                #Continue if this isn't a Verification.
                if not (elem of Verification):
                    continue

                #Handle the possibility this verifies a Transaction out of Epochs.
                if not result.weights.hasKey(cast[Verification](elem).hash.toString()):
                    continue

                try:
                    result.verify(cast[Verification](elem), state[holder], state.live, false)
                except ValueError as e:
                    doAssert(false, "Couldn't reload a Verification when reloading Transactions: " & e.msg)

#Load Verifications of previously unknown hashes.
proc loadUnknown*(
    transactions: var Transactions,
    consensus: Consensus,
    blockchain: Blockchain,
    state: var State,
    tx: Transaction
) {.forceCheck: [].} =
    #If this transaction doesn't have previously unknown Verifications, return.
    if not consensus.unknowns.hasKey(tx.hash.toString()):
        return

    #Verification.
    var verif: Verification
    try:
        for holder in consensus.unknowns[tx.hash.toString()]:
            #Recreate the Verification.
            verif = newVerificationObj(tx.hash)
            try:
                verif.holder = holder
            except FinalAttributeError as e:
                doAssert(false, "Set a final attribute twice when recreating a Verification: " & e.msg)

            #Add the Verification.
            try:
                transactions.verify(
                    verif,
                    state[holder],
                    state.live
                )
            except ValueError as e:
                doAssert(false, "Couldn't add a Verification for a Transaction we just added: " & e.msg)
    except KeyError as e:
        doAssert(false, "Couldn't get a value despite confirming we have the key: " & e.msg)

    #Delete the Transaction from unknowns.
    consensus.unknowns.del(tx.hash.toString())

#Add a Claim.
proc add*(
    transactions: var Transactions,
    claim: Claim
) {.forceCheck: [
    ValueError,
    DataExists
].} =
    #Verify it wasn't already added.
    try:
        discard transactions[claim.hash]
        raise newException(DataExists, "Claim was already added.")
    except IndexError:
        discard

    var
        #Claimers.
        claimers: seq[BLSPublicKey] = newSeq[BLSPublicKey](1)

        #Output loop variable.
        output: MintOutput
        #Amount this Claim is claiming.
        amount: uint64 = 0

    #Grab the first claimer.
    try:
         claimers[0] = transactions.loadUTXO(claim.inputs[0].hash).key
    except DBReadError:
        raise newException(ValueError, "Claim spends a non-existant or spent Mint.")

    #Add the amount the inputs provide.
    for input in claim.inputs:
        try:
            output = transactions.loadUTXO(input.hash)
        except DBreadError:
            raise newException(ValueError, "Claim spends a non-existant or spent Mint.")

        if not claimers.contains(output.key):
            claimers.add(output.key)
        amount += output.amount

    #Set the Claim's output amount to the amount.
    try:
        claim.outputs[0].amount = amount
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when adding a Claim: " & e.msg)

    #Verify the signature.
    try:
        if not claim.verify(claimers.aggregate()):
            raise newException(ValueError, "Claim has an invalid Signature.")
    except BLSError as e:
        doAssert(false, "Failed to aggregate BLS Public Keys: " & e.msg)

    #Add the Claim.
    transactions.add(cast[Transaction](claim))

#Add a Send.
proc add*(
    transactions: var Transactions,
    send: Send
) {.forceCheck: [
    ValueError,
    DataExists
].} =
    #Verify the Send's proof.
    if send.argon < transactions.difficulties.send:
        raise newException(ValueError, "Send has an invalid proof.")

    #Verify it wasn't already added.
    try:
        discard transactions[send.hash]
        raise newException(DataExists, "Send was already added.")
    except IndexError:
        discard

    #Verify the inputs length.
    if send.inputs.len == 0:
        raise newException(ValueError, "Send has no inputs.")

    var
        #Sender.
        senders: seq[EdPublicKey] = newSeq[EdPublicKey](1)

        #Spent output loop variable.
        spent: SendOutput
        #Amount this transaction is processing.
        amount: uint64 = 0

    #Grab the first sender.
    try:
        senders[0] = transactions.loadUTXO(cast[SendInput](send.inputs[0])).key
    except DBreadError:
        raise newException(ValueError, "Send spends a non-existant or spent output.")

    #Add the amount the inputs provide.
    for input in send.inputs:
        try:
            spent = transactions.loadUTXO(cast[SendInput](input))
        except DBreadError:
            raise newException(ValueError, "Send spends a non-existant or spent output.")

        if not senders.contains(spent.key):
            senders.add(spent.key)

        amount += spent.amount

    #Subtract the amount the outpts spend.
    for output in send.outputs:
        if output.amount == 0:
            raise newException(ValueError, "Send output has an amount of 0.")

        amount -= output.amount

    #If the amount is not 9, there's a problem
    #It should be noted, amount can underflow. It's impossible to spend the full underflow.
    if amount != 0:
        raise newException(ValueError, "Send outputs don't spend the amount provided by the inputs.")

    #Verify the signature.
    if not senders.aggregate().verify(send.hash.toString(), send.signature):
        raise newException(ValueError, "Send has an invalid Signature.")

    #Add the Send.
    transactions.add(cast[Transaction](send))

#Add a Data.
proc add*(
    transactions: var Transactions,
    data: Data
) {.forceCheck: [
    ValueError,
    DataExists
].} =
    #Verify the Data's proof.
    if data.argon < transactions.difficulties.data:
        raise newException(ValueError, "Data has an invalid proof.")

    #Verify it wasn't already added.
    try:
        discard transactions[data.hash]
        raise newException(DataExists, "Data was already added.")
    except IndexError:
        discard

    #Verify the inputs length.
    if data.inputs.len == 0:
        raise newException(ValueError, "Data has no inputs.")

    #Sender.
    var sender: EdPublicKey

    #Load the sender (which also verifies the input, if it's not the sender's key).
    try:
        sender = transactions.getSender(data)
    except ValueError as e:
        fcRaise e

    #Verify the input, if it is the sender's key.
    var hasData: bool
    try:
        discard transactions.loadData(sender)
        hasData = true
    except DBReadError:
        hasData = false
    if data.isFirstData and hasData:
        raise newException(ValueError, "Verified Data is 'first' yet a competing 'first' Data has already been verified.")

    #Verify the signature.
    if not sender.verify(data.hash.toString(), data.signature):
        raise newException(ValueError, "Data has an invalid Signature.")

    #Add the Data.
    transactions.add(cast[Transaction](data))

#Save a Transaction. Do not apply any other checks.
proc save*(
    transactions: Transactions,
    tx: Transaction
) {.inline, forceCheck: [].} =
    transactions.saveTransaction(tx)

#Mint Meros to the specified key.
proc mint*(
    transactions: var Transactions,
    key: BLSPublicKey,
    amount: uint64
): Hash[384] {.forceCheck: [].} =
    #Create the Mint.
    var mint: Mint = newMint(
        transactions.mintNonce,
        key,
        amount
    )

    #Add it to Transactions.
    transactions.add(cast[Transaction](mint))
    transactions.saveUTXO(mint.hash, cast[MintOutput](mint.outputs[0]))

    #Increment the mint nonce.
    inc(transactions.mintNonce)

    #Save the mint nonce.
    transactions.saveMintNonce()

    #Return the mint hash.
    result = mint.hash

#Remove every hash in this Epoch from the cache/RAM, updating archived and the amount of Elements to reload.
proc archive*(
    transactions: var Transactions,
    consensus: Consensus,
    epoch: Epoch
) {.forceCheck: [].} =
    for record in epoch.records:
        #Remove every hash from this Epoch.
        #If we used the hashes in the Epoch, we'd only remove confirmed hashes.
        #We need to iterate over every Element archived in this hash and remove every verified hash.
        var
            #Previously popped height.
            prev: int
            #Elements.
            elems: seq[Element]
        try:
            prev = transactions.load(record.key)
        except DBReadError:
            prev = -1
        try:
            elems = consensus[record.key][prev + 1 .. record.nonce]
        except IndexError as e:
            doAssert(false, "Couldn't load Elements which were archived: " & e.msg)

        #Iterate over every archived Element,
        for elem in elems:
            transactions.del(cast[Verification](elem).hash.toString())

        #Save the popped height so we can reload Elements.
        transactions.save(record.key, record.nonce)

#Checks if an Transaction was the first to spend all of its inputs.
proc isFirst*(
    transactions: Transactions,
    tx: Transaction
): bool {.forceCheck: [].} =
    for input in tx.inputs:
        if transactions.spent.hasKey(input.toString(tx)):
            return false
    result = true
