#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#Hash lib.
import ../../lib/Hash

#MinerWallet lib.
import ../../Wallet/MinerWallet

#LatticeIndex and MeritHolderRecord objects.
import ../common/objects/LatticeIndexObj
import ../common/objects/MeritHolderRecordObj
#Export the LatticeIndex object.
export LatticeIndexObj

#Consensus lib.
import ../Consensus/Consensus

#Merit lib.
import ../Merit/Merit

#DB Function Box object.
import ../../objects/GlobalFunctionBoxObj

#Entry object and Entry descendants lib.
import objects/EntryObj
import Mint
import Claim
import Send
import Receive
import Data

export EntryObj
export Mint
export Claim
export Send
export Receive
export Data

#Account lib.
import Account
export Account

#Lattice object (and sub-objects).
import objects/DifficultiesObj
import objects/LatticeObj
export Difficulties
export LatticeObj

#Seq utils standard lib.
import sequtils

#Tables standard lib.
import tables

#Add a Verification to the Elements' table.
proc verify*(
    lattice: var Lattice,
    verif: Verification,
    merit: int,
    liveMerit: int,
    save: bool = true
) {.forceCheck: [
    ValueError,
    DataExists
].} =
    #Turn the hash into a string.
    var hash: string = verif.hash.toString()

    #Verify the Entry exists.
    if not lattice.lookup.hasKey(hash):
        raise newException(ValueError, "Entry either doesn't exist or is already out of the Epochs.")

    #Create a blank seq if there's not already a seq.
    if not lattice.verifications.hasKey(hash):
        lattice.verifications[hash] = @[]
        lattice.weights[hash] = 0

    #Return if the Verification already exists.
    try:
        for holder in lattice.verifications[hash]:
            if holder == verif.holder:
                raise newException(DataExists, "Verification was already added.")
    except KeyError as e:
        doAssert(false, "Couldn't grab the Elements seq despite guarantreeing it existed: " & e.msg)

    #Add the Verification.
    try:
        lattice.verifications[hash].add(verif.holder)
    except KeyError as e:
        doAssert(false, "Couldn't add a Verification despite guaranteeing it had a seq: " & e.msg)

    #Add the new weight.
    var weight: int
    try:
        weight = lattice.weights[hash]
    except KeyError as e:
        doAssert(false, "Couldn't get an Entry's weight despite guaranteeing it had a weight: " & e.msg)
    weight += merit
    lattice.weights[hash] = weight

    #If the Entry has at least 50.1% of the weight...
    if weight > (liveMerit div 2) + 1:
        #Get the Index, Account, and calculate in `entries`.
        var
            index: LatticeIndex
            account: Account
            i: int
        try:
            index = lattice.lookup[hash]
            account = lattice[index.address]
            i = index.nonce - lattice[index.address].confirmed
        except KeyError as e:
            doAssert(false, "Couldn't grab the confirmed Entry's Index/Account/cache offsetted index: " & e.msg)
        except AddressError as e:
            doAssert(false, "Calculating the weight of a valid Entry without being able to grab the account due to an AddressError: " & e.msg)

        #Get said Entry (and calculate the max potential debt).
        var
            entry: Entry = nil
            maxDebt: uint64 = 0
        for e in account.entries[i]:
            if e.descendant == EntryType.Send:
                if cast[Send](e).amount > maxDebt:
                    maxDebt = cast[Send](e).amount

            if e.hash == verif.hash:
                entry = e
        if entry.isNil:
            doAssert(false, "Confirmed an Entry but then failed to find that Entry.")

        #Set it to verified.
        entry.verified = true

        #Remove the max potential debt from this Entry from the Account's potential debt.
        account.potentialDebt -= maxDebt

        #If we're not just reloading Elements, and should update balances/save results to the DB...
        if save:
            echo hash.toHex() & " was verified."

            #Update the balance now that the Entry is confirmed.
            var changedBalance: bool = true
            case entry.descendant:
                #If it's a Claim Entry...
                of EntryType.Claim:
                    var
                        #Cast it to a Claim.
                        claim: Claim = cast[Claim](entry)
                        #Get the Mint it's Claiming.
                        mint: Mint
                    try:
                        mint = cast[Mint](lattice["minter"][claim.mintNonce])
                    except ValueError as e:
                        doAssert(false, "Claim was confirmed before Mint, which shouldn't need any confirmed: " & e.msg)
                    except IndexError as e:
                        doAssert(false, "Confirmed Claim receives Mint that's beyond the minter height: " & e.msg)
                    except AddressError as e:
                        doAssert(false, "Couln't grab the Mint the confirmed Claim is claiming from due to an AddressError: " & e.msg)

                    #Update the balance.
                    account.balance += mint.amount
                #If it's a Send Entry...
                of EntryType.Send:
                    #Cast it to a Send.
                    var send: Send = cast[Send](entry)
                    #Update the balance.
                    account.balance -= send.amount
                #If it's a Receive Entry...
                of EntryType.Receive:
                    var
                        #Cast it to a Receive.
                        recv: Receive = cast[Receive](entry)
                        #Get the Send it's Receiving.
                        send: Send
                    try:
                        send = cast[Send](lattice[recv.input])
                    except ValueError as e:
                        doAssert(false, "Receive was confirmed before Send: " & e.msg)
                    except IndexError as e:
                        doAssert(false, "Confirmed Receive receives Send that's beyond the Account height: " & e.msg)

                    #Update the balance.
                    account.balance += send.amount
                else:
                    changedBalance = false

            #If the balance was changed, save the new Balance to the DB.
            if changedBalance:
                try:
                    lattice.db.put("lattice_" & entry.sender & "_balance", lattice.accounts[entry.sender].balance.toBinary())
                except KeyError as e:
                    doAssert(false, "Couldn't grab the confirmed Entry's sender's updated balance: " & e.msg)
                except AddressError as e:
                    doAssert(false, "Couln't grab the Send the conrfirmed Receive is receiving from due to an AddressError: " & e.msg)
                except DBWriteError as e:
                    doAssert(false, "Couldn't save an updated balance to the Database: " & e.msg)

            #If this was a Claim or a Receive, mark the input as claimed.
            if entry.descendant == EntryType.Claim:
                try:
                    lattice["minter"].rmClaimable(cast[Claim](entry).mintNonce)
                except AddressError as e:
                    doAssert(false, "Lattice is trying to recreate \"minter\" AND `newAccountObj`'s \"minter\" override for the address validity check is broken: " & e.msg)
            if entry.descendant == EntryType.Receive:
                var recv: Receive = cast[Receive](entry)
                try:
                    lattice[recv.input.address].rmClaimable(recv.input.nonce)
                except AddressError as e:
                    doAssert(false, "Created an invalid address from an Ed25519 Public Key in a Receive: " & e.msg)

#Constructor.
proc newLattice*(
    db: DatabaseFunctionBox,
    consensus: Consensus,
    merit: Merit,
    sendDiff: string,
    dataDiff: string
): Lattice {.forceCheck: [].} =
    #Create the Lattice.
    result = newLatticeObj(
        db,
        sendDiff,
        dataDiff
    )

    #Grab every MeritHolder mentioned in the last 6 Blocks of Elements.
    var holders: seq[BLSPublicKey] = @[]
    try:
        if merit.blockchain.height < 6:
            for b in 0 ..< merit.blockchain.height:
                for record in merit.blockchain[b].records:
                    holders.add(record.key)
        else:
            for b in merit.blockchain.height - 6 ..< merit.blockchain.height:
                for record in merit.blockchain[b].records:
                    holders.add(record.key)
    except IndexError as e:
        doAssert(false, "Couldn't grab a block when reloading the Lattice: " & e.msg)
    holders = holders.deduplicate()

    if holders.len == 0:
        return

    #Create a seq of States.
    var states: seq[State] = newSeq[State](
        min(merit.blockchain.height - 1, 6) + 1
    )

    #Copy the State for reverting.
    var reverted: State = merit.state
    #Fill the States.
    for s in countdown(states.len - 1, 0):
        states[s] = reverted
        reverted.revert(merit.blockchain, reverted.processedBlocks - 1)

    #Iterate over every MeritHolder.
    for holder in holders:
        #Define the tips,
        var tips: seq[int] = newSeq[int](1)

        #Grab their out-of-epoch tip from the Merit database.
        try:
            tips[0] = db.get("lattice_" & holder.toString() & "_epoch").fromBinary()
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
                doAssert(false, "Couldn't grab a Block when reloading the Lattice's Elements: " & e.msg)
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

            #Grab the State.
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

                try:
                    result.verify(verif, state[holder], state.live, false)
                except ValueError as e:
                    doAssert(false, "Couldn't reload a Verification when reloading the Lattice: " & e.msg)
                except DataExists as e:
                    doAssert(false, "Reloaded a Verification twice,  which is likely a false positive: " & e.msg)

#Add a Entry to the Lattice.
proc add*(
    lattice: var Lattice,
    entry: Entry,
    mintOverride: bool = false
) {.forceCheck: [
    ValueError,
    IndexError,
    GapError,
    AddressError,
    EdPublicKeyError,
    BLSError,
    DataExists
].} =
    #Make sure the sender is only minter when mintOverride is true.
    if (entry.descendant == EntryType.Mint) and (not mintOverride):
        doAssert(false, "Adding an Entry to minter without mintOverride being true.")

    #Get the Account.
    var account: Account
    if entry.descendant == EntryType.Mint:
        try:
            account = lattice["minter"]
        except AddressError as e:
            doAssert(false, "Lattice is trying to recreate \"minter\" AND `newAccountObj`'s \"minter\" override for the address validity check is broken: " & e.msg)
    else:
        try:
            account = lattice[entry.sender]
        except AddressError as e:
            fcRaise e

    try:
        case entry.descendant:
            of EntryType.Mint:
                #Add the casted entry.
                account.add(cast[Mint](entry))

            of EntryType.Claim:
                #Cast it to a claim.
                var claim: Claim = cast[Claim](entry)

                #Add the casted entry (and the Minter Account).
                account.add(
                    claim,
                    lattice["minter"]
                )

            of EntryType.Send:
                #Cast the Entry.
                var send: Send = cast[Send](entry)

                #Add it.
                account.add(
                    #Send Entry.
                    send,
                    #Send Difficulty.
                    lattice.difficulties.send
                )

            of EntryType.Receive:
                var recv: Receive = cast[Receive](entry)

                account.add(
                    #Receive Entry.
                    recv,
                    #Supposed Sender.
                    lattice[recv.input.address]
                )

            of EntryType.Data:
                var data: Data = cast[Data](entry)

                account.add(
                    #Data Entry.
                    data,
                    #Data Difficulty.
                    lattice.difficulties.data
                )
    except ValueError as e:
        fcRaise e
    except IndexError as e:
        fcRaise e
    except GapError as e:
        fcRaise e
    except AddressError as e:
        fcRaise e
    except EdPublicKeyError as e:
        fcRaise e
    except BLSError as e:
        fcRaise e
    except DataExists as e:
        fcRaise e

    #If this isn't a Mint, add the Entry to the lookup table.
    if entry.descendant != EntryType.Mint:
        lattice.addHash(
            entry.hash,
            newLatticeIndex(
                entry.sender,
                entry.nonce
            )
        )

proc mint*(
    lattice: var Lattice,
    key: BLSPublicKey,
    amount: uint64
): int {.forceCheck: [
    ValueError,
    IndexError,
    GapError,
    AddressError,
    EdPublicKeyError
].} =
    #Store the height as the result.
    try:
        result = lattice["minter"].height
    except AddressError as e:
        doAssert(false, "Lattice is trying to recreate \"minter\" AND `newAccountObj`'s \"minter\" override for the address validity check is broken: " & e.msg)

    #Create the Mint Entry.
    var mint: Mint
    try:
        mint = newMint(
            key,
            amount,
            result
        )
    except ValueError as e:
        fcRaise e

    #Add it to the Lattice.
    try:
        lattice.add(mint, true)
    except ValueError as e:
        fcRaise e
    except IndexError as e:
        fcRaise e
    except GapError as e:
        fcRaise e
    except AddressError as e:
        fcRaise e
    except EdPublicKeyError as e:
        fcRaise e
    except BLSError as e:
        doAssert(false, "Adding a Mint threw a BLSError, which it should never do: " & e.msg)
    except DataExists as e:
        doAssert(false, "Adding a new Mint failed because of a DataExists: " & e.msg)

    try:
        #Save the minter's new height to the DB.
        lattice.db.put("lattice_minter", lattice["minter"].height.toBinary())

        #Save the hash to the DB.
        lattice.db.put("lattice_minter_" & mint.nonce.toBinary(), mint.hash.toString())

        #Update the minter's confirmed field.
        lattice["minter"].confirmed = lattice["minter"].height
        lattice.db.put("lattice_minter_confirmed", lattice["minter"].confirmed.toBinary())
    except AddressError:
        doAssert(false, "Lattice is trying to recreate \"minter\" AND `newAccountObj`'s \"minter\" override for the address validity check is broken.")
    except DBWriteError as e:
        doAssert(false, "Couldn't write the minter's new height/confirmed and the latest mint's hash to the database: " & e.msg)

    #Clear the minter's cache.
    try:
        lattice["minter"].entries.delete(0)
    except AddressError:
        doAssert(false, "Lattice is trying to recreate \"minter\" AND `newAccountObj`'s \"minter\" override for the address validity check is broken.")

#Remove every hash in this Epoch from the cache/RAM, updating confirmed and the amount of Elements to reload.
proc archive*(
    lattice: var Lattice,
    epoch: Epoch
) {.forceCheck: [].} =
    for hash in epoch.hashes.keys():
        #Grab the Index for this hash.
        var index: LatticeIndex
        try:
            index = lattice.lookup[hash]
        #If we couldn't grab it, it's because we're handling hashes out of order and already handled this one.
        except KeyError:
            continue

        #If this index points to a newer Entry than the previously newest Entry out of Epochs...
        var confirmed: int
        try:
            confirmed = lattice[index.address].confirmed
        except AddressError as e:
            doAssert(false, "Trying to access the confirmed of an Account we're archiving, yet the Lattice just tried creating the account and detected it as invalid: " & e.msg)
        if index.nonce >= confirmed:
            #Handle all previous Entries, if we're going out of order.
            try:
                while (
                    (lattice[index.address].entries.len > 0) and
                    (lattice[index.address].entries[0][0].nonce <= index.nonce)
                ):
                    #Remove the hashes of all Entries at this position from the lookup/consensus table.
                    try:
                        for e in lattice[index.address].entries[0]:
                            lattice.rmHash(e.hash)
                    except AddressError as e:
                        doAssert(false, "Trying to clear the cache of an Account we're archiving, yet the Lattice just tried creating the account and detected it as invalid: " & e.msg)
                    except ValueError as e:
                        doAssert(false, "Couldn't access the first Entry on the Account because there's multiple Entries with none confirmed: " & e.msg)

                    #Save the verified Entry's hash to the DB under SENDER_NONCE.
                    try:
                        lattice.db.put("lattice_" & lattice[index].sender & "_" & lattice[index.address].entries[0][0].nonce.toBinary(), lattice[index.address][0].hash.toString())
                    except ValueError as e:
                        doAssert(false, "Couldn't access the first Entry on the Account because there's multiple Entries with none confirmed: " & e.msg)
                    except IndexError as e:
                        doAssert(false, "Couldn't access the first Entry on the Account, despite confirming it had one: " & e.msg)
                    except AddressError as e:
                        doAssert(false, "Trying to save the hash of a confirmed Entry to its index, yet the Lattice just tried creating the Account and detected as invalid: " & e.msg)
                    except DBWriteError as e:
                        doAssert(false, "Couldn't write the confirmed Entry's hash to its index: " & e.msg)

                    #Clear these Entries at this position.
                    lattice[index.address].entries.delete(0)

                #Update confirmed.
                lattice[index.address].confirmed = index.nonce + 1
                #Save the new confirmed to the DB.
                try:
                    lattice.db.put("lattice_" & index.address & "_confirmed", lattice[index.address].confirmed.toBinary())
                except AddressError as e:
                    doAssert(false, "Trying to save the confirmed of an Account that the Lattice just tried creating and detected it as invalid: " & e.msg)
                except DBWriteError as e:
                    doAssert(false, "Couldn't write the updated confirmed to the database: " & e.msg)
            except AddressError as e:
                doAssert(false, "Trying to access the entries of an Account we're archiving, yet the Lattice just tried creating the account and detected it as invalid: " & e.msg)

    #Save the records to lattice_VERIFIER_epoch so we can reload Elements.
    #Epoch, in the Merit DB, means the record shifted 10+ Epochs ago.
    #Here, it means the record shifted 5+ Epochs ago.
    for record in epoch.records:
        try:
            lattice.db.put("lattice_" & record.key.toString() & "_epoch", (record.nonce + 1).toBinary())
        except DBWriteError as e:
            doAssert(false, "Couldn't write a shifted record to the database: " & e.msg)
