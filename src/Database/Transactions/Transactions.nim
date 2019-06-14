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

#Transaction object, along with the Mint, Claim, and Send libraries.
import objects/TransactionObj
import Mint
import Claim
import Send

export Mint
export Claim
export Send

#Transactions object.
import objects/TransactionsObj
export TransactionsObj.Transactions, `[]`

#Seq utils standard lib.
import sequtils

#Tables standard lib.
import tables

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

    #If the Transaction has at least 50.1% of the weight (+ 600 for the Meros minted while a Transaction can be verified)...
    if weight > (liveMerit div 2) + 601:
        #Grab the Transaction.
        var tx: Transaction
        try:
            tx = transactions.transactions[hash]
        except KeyError:
            doAssert(false, "Couldn't get a Transaction despite confirming it's in the cache.")

        #If the Transaction was already verified, return.
        if tx.verified:
            return

        if not save:
            #Guarantee all spent UTXOs are still available.
            for input in tx.inputs:
                case tx.descendant:
                    of TransactionType.Claim:
                        try:
                            discard transactions.getUTXO(input.hash)
                        except DBreadError:
                            doAssert(false, "Verified Claim spends no longer spendable Mints.")

                    of TransactionType.Send:
                        try:
                            discard transactions.getUTXO(cast[SendInput](input))
                        except DBreadError:
                            doAssert(false, "Verified Send spends no longer spendable UTXOs.")

                    else:
                        discard

        #Set it to verified.
        tx.verified = true

        #If we're not just reloading Verifications, and should update UTXOs...
        if save:
            echo tx.hash, " was verified."
            transactions.verify(tx.hash)

            #Mark spent UTXOs as spent and create new UTXOs.
            case tx.descendant:
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

                else:
                    discard

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
    ValueError
].} =
    var
        #Claimer.
        claimer: BLSPublicKey

        #Output loop variable.
        output: MintOutput
        #Amount this Claim is claiming.
        amount: uint64 = 0

    #Grab the Claimer.
    try:
         claimer = transactions.getUTXO(claim.inputs[0].hash).key
    except DBreadError:
        raise newException(ValueError, "Claim spends a non-existant or spent Mint.")

    #Add the amount the inputs provide.
    for input in claim.inputs:
        try:
            output = transactions.getUTXO(input.hash)
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
    ValueError
].} =
    #Verify the Send's proof.
    if send.argon < transactions.difficulties.send:
        raise newException(ValueError, "Send has an invalid proof.")

    var
        #Sender.
        sender: EdPublicKey

        #Output loop variable.
        output: SendOutput
        #Amount this transaction is processing.
        amount: uint64 = 0

    #Grab the Sender.
    try:
        sender = transactions.getUTXO(cast[SendInput](send.inputs[0])).key
    except DBreadError:
        raise newException(ValueError, "Send spends a non-existant or spent output.")

    #Add the amount the inputs provide.
    for input in send.inputs:
        try:
            output = transactions.getUTXO(cast[SendInput](input))
        except DBreadError:
            raise newException(ValueError, "Send spends a non-existant or spent output.")

        if output.key != sender:
            raise newException(ValueError, "Send inputs have different keys.")

        amount += output.amount

    #Subtract the amount the outpts spend.
    for ouput in send.outputs:
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
