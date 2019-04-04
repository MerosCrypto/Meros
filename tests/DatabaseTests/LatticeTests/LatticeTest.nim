#Lattice Test.

#Errors lib.
import ../../../src/lib/Errors

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#Numerical libs.
import BN
import ../../../src/lib/Base

#BLS and MinerWallet libs.
import ../../../src/lib/BLS
import ../../../src/Wallet/MinerWallet

#Wallet lib.
import ../../../src/Wallet/Wallet

#Index and VerifierIndex objects.
import ../../../src/Database/common/objects/IndexObj
import ../../../src/Database/Merit/objects/VerifierIndexObj

#Verifications lib.
import ../../../src/Database/Verifications/Verifications

#Merit lib.
import ../../../src/Database/Merit/Merit

#Lattice lib.
import ../../../src/Database/Lattice/Lattice

#Serialize lib.
import ../../../src/Network/Serialize/Lattice/SerializeEntry

#Test Database lib.
import ../TestDatabase

#Tables standard lib.
import tables

discard """
On Lattice creation:
    Load `lattice_accounts`.
    For each, load the Account.
    Scan the blockchain for all Verification tips from the last 6 Blocks.
    Deduplicate the list, and grab every Verifier's archived tip from `merit_VERIFIER_epoch`.
    Load every Verification from their archived tip to their height.

On Account creation:
    If the Account doesn't exist, add them to `accountsStr` and save it.
    Load `lattice_SENDER` and `lattice_SENDER_confirmed`, which is the height and the nonce of the highest verified Entry, where all previous Entries are also Verified.
    For each Entry between confirmed and height, load it into the cache.
    If it doesn't exist, save 0, 0, 0 to `lattice_SENDER`, `lattice_SENDER_confirmed`, and `lattice_SENDER_balance`.

On Entry addition:
    Save the Entry to `lattice_HASH` (prefixed with a byte of the EntryType).
    For every unconfirmed Entry at that index, save their hashes to `lattice_SENDER_NONCE`.
    Save the Account height to `lattice_SENDER`.

On verification:
    Save the confirmed Entry's hash to `lattice_SENDER_NONCE`.
    Update the Account's confirmed value, and save it to `lattice_SENDER_confirmed`.
    If the balance was changed, save the Account balance to `lattice_SENDER_balance`.

We cache every Entry from the Account's earliest unconfirmed Entry to their tip.
We save every Entry without their verified field.
"""

import strutils

var
    #Database.
    db: DatabaseFunctionBox = newTestDatabase()

    #Verifications.
    verifications: Verifications = newVerifications(db)
    #Merit.
    merit: Merit = newMerit(
        db,
        verifications,
        "BLOCKCHAIN_TEST",
        30,
        "00AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        100
    )
    #Lattice.
    lattice: Lattice = newLattice(
        db,
        verifications,
        merit,
        "".pad(128, '0'),
        "".pad(128, '0')
    )

    #Verifiers.
    verifiers: seq[MinerWallet] = @[]
    #Accounts.
    accounts: seq[Wallet] = @[]
    #List of accounts.
    accountsStr: string

#Tests the DB's list of accounts and the reloaded Lattice against the real one.
proc test() =
    #Test the `lattice_accounts`.
    assert(db.get("lattice_accounts") == accountsStr)

    #Reload the database.
    var reloaded: Lattice = newLattice(
        db,
        verifications,
        merit,
        "".pad(128, '0'),
        "".pad(128, '0')
    )

    #Test the lookup tables.
    for hash in lattice.lookup.keys():
        assert(reloaded.lookup.hasKey(hash))
        assert(lattice.lookup[hash].key == reloaded.lookup[hash].key)
        assert(lattice.lookup[hash].nonce == reloaded.lookup[hash].nonce)
    for hash in reloaded.lookup.keys():
        assert(lattice.lookup.hasKey(hash))

    #Test the verifications tables.
    for hash in lattice.verifications.keys():
        assert(reloaded.verifications.hasKey(hash))
        for verifier in lattice.verifications[hash]:
            assert(reloaded.verifications[hash].contains(verifier))
    for hash in reloaded.verifications.keys():
        assert(lattice.verifications.hasKey(hash))
        for verifier in reloaded.verifications[hash]:
            assert(lattice.verifications[hash].contains(verifier))

    #Test each account.
    for address in lattice.accounts.keys():
        assert(reloaded.accounts.hasKey(address))

        #Grab each account.
        var
            originalAccount: Account = lattice[address]
            reloadedAccount: Account = reloaded[address]

        #Test they have the same address.
        #This should truly never fail. It's here because it's a simple check and we're better safe than sorry.
        assert(originalAccount.address == reloadedAccount.address)

        #Make sure the lookup was set to nil.
        assert(originalAccount.lookup.isNil)
        assert(reloadedAccount.lookup.isNil)

        #Check the heights and balanced are the same.
        assert(originalAccount.height == reloadedAccount.height)
        assert(originalAccount.confirmed == reloadedAccount.confirmed)
        assert(originalAccount.entries.len == reloadedAccount.entries.len)
        assert(originalAccount.balance == reloadedAccount.balance)

        #Check every Entry.
        for h in 0 ..< int(originalAccount.height):
            var
                originalEntry: Entry = lattice[address][uint(h)]
                reloadedEntry: Entry = reloaded[address][uint(h)] #<-

            assert(originalEntry.descendant == reloadedEntry.descendant)
            assert(originalEntry.sender == reloadedEntry.sender)
            assert(originalEntry.nonce == reloadedEntry.nonce)
            assert(originalEntry.hash == reloadedEntry.hash)
            assert(originalEntry.signature == reloadedEntry.signature)
            assert(originalEntry.verified == reloadedEntry.verified)

            case originalEntry.descendant:
                of EntryType.Mint:
                    assert(cast[Mint](originalEntry).output == cast[Mint](reloadedEntry).output)
                    assert(cast[Mint](originalEntry).amount == cast[Mint](reloadedEntry).amount)
                of EntryType.Claim:
                    assert(cast[Claim](originalEntry).mintNonce == cast[Claim](reloadedEntry).mintNonce)
                    assert(cast[Claim](originalEntry).bls == cast[Claim](reloadedEntry).bls)
                of EntryType.Send:
                    assert(cast[Send](originalEntry).output == cast[Send](reloadedEntry).output)
                    assert(cast[Send](originalEntry).amount == cast[Send](reloadedEntry).amount)
                    assert(cast[Send](originalEntry).proof == cast[Send](reloadedEntry).proof)
                    assert(cast[Send](originalEntry).argon == cast[Send](reloadedEntry).argon)
                of EntryType.Receive:
                    assert(cast[Receive](originalEntry).index.key == cast[Receive](reloadedEntry).index.key)
                    assert(cast[Receive](originalEntry).index.nonce == cast[Receive](reloadedEntry).index.nonce)
                of EntryType.Data:
                    assert(cast[Data](originalEntry).data == cast[Data](reloadedEntry).data)
                    assert(cast[Data](originalEntry).proof == cast[Data](reloadedEntry).proof)
                    assert(cast[Data](originalEntry).argon == cast[Data](reloadedEntry).argon)
    for address in reloaded.accounts.keys():
        assert(lattice.accounts.hasKey(address))

#Adds a Block which assigns all new Merit to the passed MinerWallet.
proc addBlock(wallet: MinerWallet) =
    var mining: Block = newBlockObj(
        1,
        merit.blockchain.tip.header.hash,
        nil,
        @[],
        @[
            newMinerObj(
                wallet.publicKey,
                100
            )
        ],
        getTime(),
        0
    )
    while not merit.blockchain.difficulty.verifyDifficulty(mining):
        inc(mining)
    try:
        discard merit.processBlock(verifications, mining)
    except:
        raise newException(ValueError, "Valid Block wasn't successfully added.")

#Adds a Verification for an Entry.
proc verify(wallet: MinerWallet, hash: string) =
    var verif: MemoryVerification = newMemoryVerificationObj(hash.toHash(512))
    wallet.sign(verif, verifications[wallet.publicKey.toString()].height)
    verifications.add(verif)
    assert(lattice.verify(merit, verif))

#Create three Verifiers.
for i in 0 ..< 3:
    verifiers.add(newMinerWallet())

#Create ten Accounts.
for i in 0 ..< 10:
    accounts.add(newWallet())

#Mine a Block assigning Verifier 1 all of the Merit.
addBlock(verifiers[0])

#Mint some coins to the first Verifier, and claim them by the first Account.
assert(lattice.mint(verifiers[0].publicKey.toString(), newBN(300)) == 0)
assert(db.get("lattice_" & db.get("lattice_minter_" & 0.toBinary())) == char(EntryType.Mint) & lattice["minter"][0].serialize())

var claim: Claim = newClaim(0, 0)
claim.sign(verifiers[0], accounts[0])
assert(lattice.add(claim))
assert(db.get("lattice_" & claim.hash.toString()) == char(claim.descendant) & claim.serialize())

#Verify the Claim so we can spend those funds.
verifiers[0].verify(lattice[accounts[0].address][0].hash.toString())

#Send 100 Meros to the second account, and 50 to the third.
var send: Send = newSend(accounts[1].address, newBN(100), 1)
accounts[0].sign(send)
send.mine("".pad(128, '0').toBN(16))
assert(lattice.add(send))
assert(db.get("lattice_" & send.hash.toString()) == char(send.descendant) & send.serialize())

send = newSend(accounts[2].address, newBN(50), 2)
accounts[0].sign(send)
send.mine("".pad(128, '0').toBN(16))
assert(lattice.add(send))
assert(db.get("lattice_" & send.hash.toString()) == char(send.descendant) & send.serialize())

#Update the accountsStr.
accountsStr &= accounts[0].address

#Test.
test()

#Verify every the Sends on the first account.
verifiers[0].verify(lattice[accounts[0].address][1].hash.toString())
verifiers[0].verify(lattice[accounts[0].address][2].hash.toString())

#Create Receives on both accounts.
var recv: Receive = newReceive(newIndex(accounts[0].address, 1), 0)
accounts[1].sign(recv)
assert(lattice.add(recv))
assert(db.get("lattice_" & recv.hash.toString()) == char(recv.descendant) & recv.serialize())

recv = newReceive(newIndex(accounts[0].address, 2), 0)
accounts[2].sign(recv)
assert(lattice.add(recv))
assert(db.get("lattice_" & recv.hash.toString()) == char(recv.descendant) & recv.serialize())

#Verify the second account's Receive.
verifiers[0].verify(lattice[accounts[1].address][0].hash.toString())

#Add a Data to the second account.
var data: Data = newData("1", 1)
accounts[1].sign(data)
data.mine("".pad(128, '0').toBN(16))
assert(lattice.add(data))
assert(db.get("lattice_" & data.hash.toString()) == char(data.descendant) & data.serialize())

#Update the accountsStr.
accountsStr &= accounts[1].address
accountsStr &= accounts[2].address

#Test.
test()

#Verify everything else, and do another test.
verifiers[0].verify(lattice[accounts[1].address][1].hash.toString())
verifiers[0].verify(lattice[accounts[2].address][0].hash.toString())
test()

echo "Finished the Database/Lattice/Lattice Test."
