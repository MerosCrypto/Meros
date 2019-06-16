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

#Transaction object, along with the Mint, Claim, and Send libraries.
import objects/TransactionObj
import Mint
import Claim
import Send
import Data

export Mint
export Claim
export Send
export Data

#Transactions object.
import objects/TransactionsObj
export TransactionsObj.Transactions, `[]`, getUTXOs

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
        (tx.descendant == TransactionType.Data) and
        (cast[Data](tx).isFirstData)
    ):
        var inputStr: string
        for input in tx.inputs:
            inputStr = input.toString(tx.descendant)

            #If a previous TX marked this input as spent, don't overwrite it.
            if transactions.spent.hasKey(inputStr):
                continue

            transactions.spent[inputStr] = tx.hash

    #If the Transaction has at least 50.1% of the weight (+ 600 for the Meros minted while a Transaction can be verified)...
    if weight > (liveMerit div 2) + 601:
        #If the Transaction was already verified, return.
        if tx.verified:
            return

        #Guarantee all spent UTXOs are still available.
        if not save:
            for input in tx.inputs:
                case tx.descendant:
                    of TransactionType.Mint:
                        discard

                    of TransactionType.Claim:
                        try:
                            discard transactions.loadUTXO(input.hash)
                        except DBreadError:
                            doAssert(false, "Verified Claim spends no longer spendable Mints.")

                    of TransactionType.Send:
                        try:
                            discard transactions.loadUTXO(cast[SendInput](input))
                        except DBreadError:
                            doAssert(false, "Verified Send spends no longer spendable UTXOs.")

                    of TransactionType.Data:
                        discard

            if tx.descendant == TransactionType.Data:
                try:
                    if cast[Data](tx).isFirstData and transactions.hasData(transactions.getSender(cast[Data](tx))):
                        doAssert(false, "Verified Data is 'first' yet a competing 'first' Data is already verified.")
                except ValueError:
                    doAssert(false, "Verified Data 'spends' an unknown/spent Data.")

        #Set it to verified.
        tx.verified = true

        #If we're not just reloading Verifications, and should update UTXOs...
        if save:
            echo tx.descendant, " ", tx.hash, " was verified."
            transactions.verify(tx.hash)

            #Mark spent UTXOs as spent and create new UTXOs.
            case tx.descendant:
                of TransactionType.Mint:
                    discard

                of TransactionType.Claim:
                    #Up to 255 Mint UTXOs spent.
                    for input in tx.inputs:
                        transactions.spend(input.hash)
                    #Svae the output.
                    transactions.saveUTXOs(tx.hash, cast[seq[SendOutput]](tx.outputs))

                of TransactionType.Send:
                    #Up to 255 Send UTXOs spent.
                    for input in tx.inputs:
                        transactions.spend(cast[SendInput](input))
                    #Svae the outputs.
                    transactions.saveUTXOs(tx.hash, cast[seq[SendOutput]](tx.outputs))

                of TransactionType.Data:
                    #Save this as the tip data.
                    var sender: EdPublicKey
                    try:
                        sender = transactions.getSender(cast[Data](tx))
                    except ValueError as e:
                        doAssert(false, "Couldn't get the sender of an added Data: " & e.msg)
                    transactions.saveData(sender, tx.hash)

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
                var verif: Verification
                try:
                    verif = consensus[holder][e]
                except IndexError as e:
                    doAssert(false, "Couldn't grab a Verification we know we have: " & e.msg)

                #Handle the possibility this verifies a Transaction out of Epochs.
                if not result.weights.hasKey(verif.hash.toString()):
                    continue

                try:
                    result.verify(verif, state[holder], state.live, false)
                except ValueError as e:
                    doAssert(false, "Couldn't reload a Verification when reloading Transactions: " & e.msg)
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
        #Claimer.
        claimer: BLSPublicKey

        #Output loop variable.
        output: MintOutput
        #Amount this Claim is claiming.
        amount: uint64 = 0

    #Grab the Claimer.
    try:
         claimer = transactions.loadUTXO(claim.inputs[0].hash).key
    except DBReadError:
        raise newException(ValueError, "Claim spends a non-existant or spent Mint.")

    #Add the amount the inputs provide.
    for input in claim.inputs:
        try:
            output = transactions.loadUTXO(input.hash)
        except DBreadError:
            raise newException(ValueError, "Claim spends a non-existant or spent Mint.")

        if output.key != claimer:
            raise newException(ValueError, "Claim inputs have different keys.")

        amount += output.amount

    #Set the Claim's output amount to the amount.
    try:
        claim.outputs[0].amount = amount
    except FinalAttributeError as e:
        doAssert(false, "Set a final attribute twice when adding a Claim: " & e.msg)

    #Verify the signature.
    if not claim.verify(claimer):
        raise newException(ValueError, "Claim has an invalid Signature.")

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
        sender: EdPublicKey

        #Spent output loop variable.
        spent: SendOutput
        #Amount this transaction is processing.
        amount: uint64 = 0

    #Grab the Sender.
    try:
        sender = transactions.loadUTXO(cast[SendInput](send.inputs[0])).key
    except DBreadError:
        raise newException(ValueError, "Send spends a non-existant or spent output.")

    #Add the amount the inputs provide.
    for input in send.inputs:
        try:
            spent = transactions.loadUTXO(cast[SendInput](input))
        except DBreadError:
            raise newException(ValueError, "Send spends a non-existant or spent output.")

        if spent.key != sender:
            raise newException(ValueError, "Send inputs have different keys.")

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
    if not sender.verify(send.hash.toString(), send.signature):
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
    if data.isFirstData and transactions.hasData(sender):
        raise newException(ValueError, "Verified Data is 'first' yet a competing 'first' Data has already been verified.")

    #Verify the signature.
    if not sender.verify(data.hash.toString(), data.signature):
        raise newException(ValueError, "Data has an invalid Signature.")

    #Add the Send.
    transactions.add(cast[Transaction](data))

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
            elems: seq[Verification]
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
            transactions.del(elem.hash.toString())

        #Save the popped height so we can reload Elements.
        try:
            transactions.save(record.key, record.nonce)
        except DBWriteError as e:
            doAssert(false, "Couldn't write a shifted record to the database: " & e.msg)

#Checks if an Transaction was the first to spend all of its inputs.
proc isFirst*(
    transactions: Transactions,
    tx: Transaction
): bool {.forceCheck: [].} =
    for input in tx.inputs:
        try:
            if transactions.spent[input.toString(tx.descendant)] != tx.hash:
                return false
        except KeyError as e:
            doAssert(false, "Spent input isn't in the spent table: " & e.msg)
    result = true
