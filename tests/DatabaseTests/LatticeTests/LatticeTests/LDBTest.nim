#Lattice Test.

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Wallet lib.
import ../../../../src/Wallet/Wallet

#MeritHolderRecord object.
import ../../../../src/Database/common/objects/MeritHolderRecordObj

#Consensus lib.
import ../../../../src/Database/Consensus/Consensus

#Merit lib.
import ../../../../src/Database/Merit/Merit

#Lattice lib.
import ../../../../src/Database/Lattice/Lattice

#Test Database lib.
import ../../TestDatabase

#Test Lattice lib.
import ../TestLattice

#Random standard lib.
import random

#Seed random.
randomize(getTime())

discard """
On Lattice creation:
    Load `lattice_accounts`.
    For each, load the Account.
    Scan the blockchain for all Verification tips from the last 6 Blocks.
    Deduplicate the list, and grab every MeritHolder's archived tip from `merit_VERIFIER_epoch`.
    Load every Verification from their archived tip to their height.

On Account creation:
    If the Account doesn't exist, add them to `accountsStr` and save it.
    Load `lattice_SENDER`, `lattice_SENDER_archived`, and `lattice_SENDER_claimable`, which are the height and the nonce of the highest Entry out of epochs, as well as the nonces of the Claims/Sends which can be claimed.
    For each Entry between archived and height, load it into the cache.
    If it doesn't exist, save 0, 0, 0, "" to `lattice_SENDER`, `lattice_SENDER_archived`, `lattice_SENDER_balance`, and `lattice_SENDER_claimable`.

On Entry addition:
    Save the Entry to `lattice_HASH` (prefixed with a byte of the EntryType).
    For every unarchived Entry at that index, save their hashes to `lattice_SENDER_NONCE`.
    Save the Account height to `lattice_SENDER`.
    If this is a Mint or Send, add the NONCE to `lattice_SENDER_claimable`.

On verification:
    Save the verified Entry's hash to `lattice_SENDER_NONCE`.
    Update the Account's archived value, and save it to `lattice_SENDER_archived`.
    If the balance was changed, save the Account balance to `lattice_SENDER_balance`.
    If this is a Claim or Receive, remove the NONCE of the claimed Entry from the claimed Entry's sender's `lattice_SENDER_claimable`.

We cache every Entry that has yet to exit the Epochs.
We save every Entry without their verified field.
"""

var
    #Database.
    db: DatabaseFunctionBox = newTestDatabase()

    #Consensus.
    consensus: Consensus = newConsensus(db)
    #Merit.
    merit: Merit = newMerit(
        db,
        consensus,
        "BLOCKCHAIN_TEST",
        30,
        "00AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        100
    )
    #Lattice.
    lattice: Lattice = newLattice(
        db,
        consensus,
        merit,
        "".pad(48, "33"),
        "".pad(48, "33")
    )

    #MeritHolders.
    holders: seq[MinerWallet] = @[]
    #Accounts.
    wallets: seq[Wallet] = @[]

    #Pending Sends.
    sends: seq[Send] = @[]

#Tests the Lattice against the reloaded Lattice.
proc test() =
    echo "Reloading and testing the Lattice..."
    var reloaded: Lattice = newLattice(
        db,
        consensus,
        merit,
        $lattice.difficulties.send,
        $lattice.difficulties.data
    )

    compare(
        lattice,
        reloaded
    )

#Adds a Block, containing the passed records.
proc addBlock() =
    var
        #Records.
        records: seq[MeritHolderRecord] = @[]
        #Holders we're assigning new Merit.
        paying: seq[BLSPublicKey]
        #Create the Miners objects.
        miners: seq[Miner] = @[]
        #Remaining amount of Merit.
        remaining: int = 100

    #Create the Records for every MeritHolder.
    for holder in holders:
        if consensus[holder.publicKey].archived + 1 < consensus[holder.publicKey].height:
            records.add(
                newMeritHolderRecord(
                    holder.publicKey,
                    consensus[holder.publicKey].height - 1,
                    "".pad(48).toHash(384)
                )
            )

    #Grab holders to pay.
    for holder in holders:
        #Select any holders with 0 Merit.
        if merit.state[holder.publicKey] == 0:
            paying.add(holder.publicKey)
        #Else, give them a 50% chance.
        else:
            if rand(100) > 50:
                paying.add(holder.publicKey)
    #If we didn't add any holders, pick one at random.
    if paying.len == 0:
        paying.add(holders[rand(holders.len - 1)].publicKey)

    for i in 0 ..< paying.len:
        #Set the amount to pay the miner.
        var amount: int = rand(remaining - 1) + 1

        #Make sure everyone gets at least 1 and we don't go over 100.
        if (remaining - amount) < (paying.len - i):
            amount = 1

        #But if this is the last account...
        if i == paying.len - 1:
            amount = remaining

        #Add the miner.
        miners.add(
            newMinerObj(
                paying[i],
                amount
            )
        )

        remaining -= amount

    #Create the new Block.
    var newBlock: Block = newBlockObj(
        merit.blockchain.height,
        merit.blockchain.tip.header.hash,
        nil,
        records,
        newMinersObj(miners),
        getTime(),
        0
    )

    #Mine it.
    while not merit.blockchain.difficulty.verify(newBlock.header.hash):
        inc(newBlock)

    #Add it,
    var epoch: Epoch
    try:
        epoch = merit.processBlock(consensus, newBlock)
    except:
        doAssert(false, "Valid Block wasn't successfully added: " & getCurrentExceptionMsg())

    #Archive the Records.
    consensus.archive(newBlock.records)
    lattice.archive(epoch)

#Add Verifications for an Entry.
proc verify(
    hash: Hash[384],
    mustVerify: bool = false
) =
    #List of MeritHolders being used to verify this hash.
    var verifiers: seq[MinerWallet]
    if mustVerify:
        verifiers = holders
    else:
        #Grab holders to verify wuth.
        for holder in holders:
            if rand(100) > 50:
                verifiers.add(holder)
        #If we didn't add any holders, pick one at random.
        if verifiers.len == 0:
            verifiers.add(holders[rand(holders.len - 1)])

    #Verify with each Verifier.
    for verifier in verifiers:
        var verif: SignedVerification = newSignedVerificationObj(hash)
        verifier.sign(verif, consensus[verifier.publicKey].height)
        consensus.add(verif)
        lattice.verify(verif, merit.state[verifier.publicKey], merit.state.live)

#Create a random amount of MeritHolders.
for i in 0 ..< rand(2) + 1:
    holders.add(newMinerWallet())
#Assign them Merit.
addBlock()

#Iterate over 20 'rounds'.
for i in 0 ..< 20:
    #Create a random amount of Accounts.
    for i in 0 ..<  rand(2) + 1:
        wallets.add(newWallet())

    #Iterate over each pending Send.
    var i: int = 0
    while i < sends.len:
        #If the odds are not in its favor, continue. We want to wait ~6 rounds.
        if rand(7) != 0:
            inc(i)
            continue

        #Create the Receive.
        var recv: Receive = newReceive(
            newLatticeIndex(
                sends[i].sender,
                sends[i].nonce
            ),
            lattice[sends[i].output].height
        )

        #Sign it.
        for wallet in wallets:
            if wallet.address == sends[i].output:
                wallet.sign(recv)
                break

        #Add it.
        lattice.add(recv)
        verify(recv.hash)

        #Remove it from the list of pending Sends.
        sends.del(i)

    #Create Entries and Verify them.
    for e in 0 ..< rand(10):
        var
            #Grab a random account.
            sender: int = rand(wallets.len - 1)
            account: Account = lattice[wallets[sender].address]

        #Create a Send.
        if rand(2) == 0:
            #Decide how much to Send.
            var amount: uint64 = uint64(rand(10000))

            #Fund them if they need funding.
            if account.balance < amount:
                #Create the Mint.
                var
                    mintee: MinerWallet = newMinerWallet()
                    mintNonce: int = lattice.mint(mintee.publicKey, amount - account.balance + uint64(rand(5000)))

                #Create the Claim.
                var claim: Claim = newClaim(mintNonce, account.height)
                claim.sign(mintee, wallets[sender])
                lattice.add(claim)
                verify(claim.hash, true)

            #Create the Send.
            var send: Send = newSend(wallets[rand(wallets.len - 1)].address, amount, account.height)
            wallets[sender].sign(send)
            send.mine(lattice.difficulties.send)
            lattice.add(send)
            verify(send.hash, true)

            #Push the Send onto the list of pending Sends.
            sends.add(send)
        #Create a Data.
        else:
            var
                text: string = newString(rand(255 - 1) + 1)
                data: Data = newData(text, account.height)
            wallets[sender].sign(data)
            data.mine(lattice.difficulties.data)
            lattice.add(data)
            verify(data.hash)

    #Create a random amount of MeritHolders.
    for i in 0 ..< rand(3):
        holders.add(newMinerWallet())

    #Mine a Block.
    addBlock()

    #Test the Lattices.
    test()

echo "Finished the Database/Lattice/Lattice/DB Test."
