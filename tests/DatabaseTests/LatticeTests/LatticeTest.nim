#Lattice Test.

#Errors lib.
import ../../../src/lib/Errors

#Util lib.
import ../../../src/lib/Util

#Hash lib.
import ../../../src/lib/Hash

#MinerWallet lib.
import ../../../src/Wallet/MinerWallet

#Wallet lib.
import ../../../src/Wallet/Wallet

#LatticeIndex and VerifierRecord objects.
import ../../../src/Database/common/objects/LatticeIndexObj
import ../../../src/Database/common/objects/VerifierRecordObj

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
    Load `lattice_SENDER`, `lattice_SENDER_confirmed`, and `lattice_SENDER_claimable`, which are the height and the nonce of the highest Entry out of epochs, as well as the nonces of the Claims/Sends which can be claimed.
    For each Entry between confirmed and height, load it into the cache.
    If it doesn't exist, save 0, 0, 0, "" to `lattice_SENDER`, `lattice_SENDER_confirmed`, `lattice_SENDER_balance`, and `lattice_SENDER_claimable`.

On Entry addition:
    Save the Entry to `lattice_HASH` (prefixed with a byte of the EntryType).
    For every unconfirmed Entry at that index, save their hashes to `lattice_SENDER_NONCE`.
    Save the Account height to `lattice_SENDER`.
    If this is a Mint or Send, add the NONCE to `lattice_SENDER_claimable`.

On verification:
    Save the confirmed Entry's hash to `lattice_SENDER_NONCE`.
    Update the Account's confirmed value, and save it to `lattice_SENDER_confirmed`.
    If the balance was changed, save the Account balance to `lattice_SENDER_balance`.
    If this is a Claim or Receive, remove the NONCE of the claimed Entry from the claimed Entry's sender's `lattice_SENDER_claimable`.

We cache every Entry that has yet to exit the Epochs.
We save every Entry without their verified field.
"""

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
        "00AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        100
    )
    #Lattice.
    lattice: Lattice = newLattice(
        db,
        verifications,
        merit,
        "".pad(96, '0'),
        "".pad(96, '0')
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

    echo "Reloading the Lattice..."

    #Reload the database.
    var reloaded: Lattice = newLattice(
        db,
        verifications,
        merit,
        "".pad(96, '0'),
        "".pad(96, '0')
    )

    for hash in lattice.lookup.keys():
        assert(reloaded.lookup.hasKey(hash))
        assert(lattice.lookup[hash].address == reloaded.lookup[hash].address)
        assert(lattice.lookup[hash].nonce == reloaded.lookup[hash].nonce)
    for hash in reloaded.lookup.keys():
        assert(lattice.lookup.hasKey(hash))

    #Test the verifications tables.
    for hash in lattice.verifications.keys():
        assert(reloaded.verifications.hasKey(hash))
        assert(lattice.verifications[hash].len == reloaded.verifications[hash].len)
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

        #Check the rest of the fields.
        assert(originalAccount.balance == reloadedAccount.balance)

        assert(originalAccount.height == reloadedAccount.height)
        assert(originalAccount.confirmed == reloadedAccount.confirmed)

        assert(originalAccount.entries.len == reloadedAccount.entries.len)
        assert(originalAccount.claimableStr == reloadedAccount.claimableStr)
        assert(originalAccount.claimable.len == reloadedAccount.claimable.len)
        for key in originalAccount.claimable.keys():
            assert(reloadedAccount.claimable.hasKey(key))

        assert(originalAccount.potentialDebt == reloadedAccount.potentialDebt)

        #Check every Entry.
        for h in 0 ..< originalAccount.height:
            var
                originalEntries: seq[Entry]
                reloadedEntries: seq[Entry]
            if h < originalAccount.confirmed:
                originalEntries = @[originalAccount[h]]
                reloadedEntries = @[reloadedAccount[h]]
            else:
                originalEntries = originalAccount.entries[int(h - reloadedAccount.confirmed)]
                reloadedEntries = reloadedAccount.entries[int(h - reloadedAccount.confirmed)]

            for e in 0 ..< originalEntries.len:
                assert(originalEntries[e].descendant == reloadedEntries[e].descendant)
                assert(originalEntries[e].sender == reloadedEntries[e].sender)
                assert(originalEntries[e].nonce == reloadedEntries[e].nonce)
                assert(originalEntries[e].hash == reloadedEntries[e].hash)
                assert(originalEntries[e].signature == reloadedEntries[e].signature)
                #We don't test Verified because we test the verifications table and https://github.com/MerosCrypto/Meros/issues/55.

                case originalEntries[e].descendant:
                    of EntryType.Mint:
                        assert(cast[Mint](originalEntries[e]).output == cast[Mint](reloadedEntries[e]).output)
                        assert(cast[Mint](originalEntries[e]).amount == cast[Mint](reloadedEntries[e]).amount)
                    of EntryType.Claim:
                        assert(cast[Claim](originalEntries[e]).mintNonce == cast[Claim](reloadedEntries[e]).mintNonce)
                        assert(cast[Claim](originalEntries[e]).bls == cast[Claim](reloadedEntries[e]).bls)
                    of EntryType.Send:
                        assert(cast[Send](originalEntries[e]).output == cast[Send](reloadedEntries[e]).output)
                        assert(cast[Send](originalEntries[e]).amount == cast[Send](reloadedEntries[e]).amount)
                        assert(cast[Send](originalEntries[e]).proof == cast[Send](reloadedEntries[e]).proof)
                        assert(cast[Send](originalEntries[e]).argon == cast[Send](reloadedEntries[e]).argon)
                    of EntryType.Receive:
                        assert(cast[Receive](originalEntries[e]).index.address == cast[Receive](reloadedEntries[e]).index.address)
                        assert(cast[Receive](originalEntries[e]).index.nonce == cast[Receive](reloadedEntries[e]).index.nonce)
                    of EntryType.Data:
                        assert(cast[Data](originalEntries[e]).data == cast[Data](reloadedEntries[e]).data)
                        assert(cast[Data](originalEntries[e]).proof == cast[Data](reloadedEntries[e]).proof)
                        assert(cast[Data](originalEntries[e]).argon == cast[Data](reloadedEntries[e]).argon)
    for address in reloaded.accounts.keys():
        assert(lattice.accounts.hasKey(address))

#Adds a Block which assigns all new Merit to the passed MinerWallet.
proc addBlock(wallets: seq[MinerWallet], records: seq[VerifierRecord]) =
    var miners: seq[Miner] = @[]
    for wallet in wallets:
        miners.add(
            newMinerObj(
                wallet.publicKey,
                100 div wallets.len
            )
        )
    if 100 mod wallets.len != 0:
        miners.add(
            newMinerObj(
                newMinerWallet().publicKey,
                100 mod wallets.len
            )
        )

    var mining: Block = newBlockObj(
        merit.blockchain.height,
        merit.blockchain.tip.header.hash,
        nil,
        records,
        newMinersObj(miners),
        getTime(),
        0
    )
    while not merit.blockchain.difficulty.verify(mining.header.hash):
        inc(mining)
    try:
        var res: Epoch = merit.processBlock(verifications, mining)
        lattice.archive(res)
    except:
        raise newException(ValueError, "Valid Block wasn't successfully added. " & getCurrentExceptionMsg())

#Adds a Verification for an Entry.
proc verify(wallet: MinerWallet, hash: string) =
    var verif: MemoryVerification = newMemoryVerificationObj(hash.toHash(384))
    wallet.sign(verif, verifications[wallet.publicKey].height)
    verifications.add(verif)
    lattice.verify(verif, merit.state[wallet.publicKey], merit.state.live)

#Create three Verifiers.
for i in 0 ..< 3:
    verifiers.add(newMinerWallet())

#Create three Accounts.
for i in 0 ..< 3:
    accounts.add(newWallet())

#Mine a Block assigning Verifier 1 all of the Merit.
addBlock(@[verifiers[0]], @[])

#Mint some coins to the first Verifier, and claim them by the first Account.
assert(lattice.mint(verifiers[0].publicKey, 300) == 0)
assert(db.get("lattice_" & db.get("lattice_minter_" & 0.toBinary())) == char(EntryType.Mint) & lattice["minter"][0].serialize())

var claim: Claim = newClaim(0, 0)
claim.sign(verifiers[0], accounts[0])
lattice.add(claim)
assert(db.get("lattice_" & claim.hash.toString()) == char(claim.descendant) & claim.serialize())

#Verify the Claim so we can spend those funds.
verifiers[0].verify(lattice[accounts[0].address][0].hash.toString())

#Send 100 Meros to the second account, and 50 to the third.
var send: Send = newSend(accounts[1].address, 100, 1)
accounts[0].sign(send)
send.mine("".pad(48).toHash(384))
lattice.add(send)
assert(db.get("lattice_" & send.hash.toString()) == char(send.descendant) & send.serialize())

send = newSend(accounts[2].address, 50, 2)
accounts[0].sign(send)
send.mine("".pad(96, '0').toHash(384))
lattice.add(send)
assert(db.get("lattice_" & send.hash.toString()) == char(send.descendant) & send.serialize())

#Update the accountsStr.
accountsStr &= accounts[0].address

#Archive the Verification.
addBlock(
    @[
        verifiers[0]
    ],
    @[
        newVerifierRecord(verifiers[0].publicKey, 0, "".pad(48).toHash(384))
    ]
)

#Test.
test()

#Verify every the Sends on the first account.
verifiers[0].verify(lattice[accounts[0].address][1].hash.toString())
verifiers[0].verify(lattice[accounts[0].address][2].hash.toString())

#Create Receives on both accounts.
var recv: Receive = newReceive(newLatticeIndex(accounts[0].address, 1), 0)
accounts[1].sign(recv)
lattice.add(recv)
assert(db.get("lattice_" & recv.hash.toString()) == char(recv.descendant) & recv.serialize())

recv = newReceive(newLatticeIndex(accounts[0].address, 2), 0)
accounts[2].sign(recv)
lattice.add(recv)
assert(db.get("lattice_" & recv.hash.toString()) == char(recv.descendant) & recv.serialize())

#Verify the second account's Receive.
verifiers[0].verify(lattice[accounts[1].address][0].hash.toString())

#Add a Data to the second account.
var data: Data = newData("1", 1)
accounts[1].sign(data)
data.mine("".pad(96, '0').toHash(384))
lattice.add(data)
assert(db.get("lattice_" & data.hash.toString()) == char(data.descendant) & data.serialize())

#Update the accountsStr.
accountsStr &= accounts[1].address
accountsStr &= accounts[2].address

#Archive the Verifications and test.
addBlock(
    @[
        verifiers[0],
        verifiers[1],
        verifiers[2]
    ],
    @[
        newVerifierRecord(verifiers[0].publicKey, 3, "".pad(48).toHash(384))
    ]
)
test()

#Verify everything else, and do another test.
verifiers[0].verify(lattice[accounts[1].address][1].hash.toString())
verifiers[0].verify(lattice[accounts[2].address][0].hash.toString())
addBlock(
    @[
        verifiers[0],
        verifiers[1],
        verifiers[2]
    ],
    @[
        newVerifierRecord(verifiers[0].publicKey, 5, "".pad(48).toHash(384))
    ]
)
test()

#Give two other Verifiers Merit.
addBlock(
    @[verifiers[1]],
    @[]
)
addBlock(@[verifiers[2]], @[])

#Add a Data to the first account.
data = newData("2", 3)
accounts[0].sign(data)
data.mine("".pad(96, '0').toHash(384))
lattice.add(data)
assert(db.get("lattice_" & data.hash.toString()) == char(data.descendant) & data.serialize())

#Add a conflicting Data.
data = newData("3", 3)
accounts[0].sign(data)
data.mine("".pad(96, '0').toHash(384))
lattice.add(data)
assert(db.get("lattice_" & data.hash.toString()) == char(data.descendant) & data.serialize())

#Partially verify each of them.
verifiers[0].verify(lattice[accounts[0].address].entries[3][0].hash.toString())
assert(not lattice[accounts[0].address].entries[3][0].verified)
verifiers[1].verify(lattice[accounts[0].address].entries[3][1].hash.toString())
assert(not lattice[accounts[0].address].entries[3][1].verified)

#Archive these Verifications in a Block.
#In real life, if the Verifications don't make it into a Block, we'd redownload them when the next Block came through and process the Verifications then.
addBlock(
    @[
        verifiers[0],
        verifiers[1],
        verifiers[2]
    ],
    @[
        newVerifierRecord(verifiers[0].publicKey, 6, "".pad(48).toHash(384)),
        newVerifierRecord(verifiers[1].publicKey, 0, "".pad(48).toHash(384))
    ]
)
verifications.archive(merit.blockchain.tip.records)
#Test.
test()

#Finish verifying the second Data.
var hash: Hash[384] = lattice[accounts[0].address].entries[2][1].hash
verifiers[2].verify(hash.toString())
assert(lattice[accounts[0].address][3].hash == hash)
assert(lattice[accounts[0].address][3].verified)

#Archive the Verification.
addBlock(
    @[
        verifiers[0],
        verifiers[1],
        verifiers[2]
    ],
    @[
        newVerifierRecord(verifiers[2].publicKey, 0, "".pad(48).toHash(384))
    ]
)

#Test.
test()

echo "Finished the Database/Lattice/Lattice Test."
