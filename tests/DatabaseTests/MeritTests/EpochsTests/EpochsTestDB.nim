#Epochs DB Test.

#Errors lib.
import ../../../../src/lib/Errors

#Util lib.
import ../../../../src/lib/Util

#Hash lib.
import ../../../../src/lib/Hash

#MinerWallet lib.
import ../../../../src/Wallet/MinerWallet

#Verifications lib.
import ../../../../src/Database/Verifications/Verifications

#VerifierRecord object.
import ../../../../src/Database/common/objects/VerifierRecordObj

#Miners object.
import ../../../../src/Database/Merit/objects/MinersObj

#Difficulty, Block, and Blockchain libs.
import ../../../../src/Database/Merit/Difficulty
import ../../../../src/Database/Merit/Block
import ../../../../src/Database/Merit/Blockchain

#Epochs lib.
import ../../../../src/Database/Merit/Epochs

#Merit Testing functions.
import ../TestMerit

#Tables standard lib.
import tables

proc test(blocks: int) =
    echo "Testing Epoch shifting and DB interactions with " & $blocks & " blocks."

    var
        #Database.
        db: DatabaseFunctionBox = newTestDatabase()
        #Verifications.
        verifications: Verifications = newVerifications(db)
        #Blockchain.
        blockchain: Blockchain = newBlockchain(
            db,
            "EPOCHS_TEST_DB",
            30,
            "".pad(48).toHash(384)
        )
        #Epochs.
        epochs: Epochs = newEpochs(
            db,
            verifications,
            blockchain
        )
        #MinerWallets.
        wallets: seq[MinerWallet]
        #Miners we're mining to.
        miners: Miners
        #Hashes we're verifying.
        hashes: seq[seq[Hash[384]]] = @[]
        #Table of hashes -> verifiers.
        verified: Table[string, seq[BLSPublicKey]] = initTable[string, seq[BLSPublicKey]]()
        #VerifierRecords.
        records: seq[seq[VerifierRecord]] = @[]
        #Block we're mining.
        mining: Block
        #Epoch we popped.
        epoch: Epoch

    #Add 5 blank seqs to hashes for the 5 blank Epochs we start with.
    for i in 0 ..< 5:
        hashes.add(@[])

    #Add 10 blank seqs to records.
    for i in 0 ..< 10:
        records.add(@[])

    #Mine blocks blocks.
    for i in 1 .. blocks:
        echo "Mining Block " & $i & "."

        #Add a new miner.
        wallets.add(newMinerWallet())

        #Create the list of miners.
        miners = newMinersObj(@[])
        for m in 0 ..< wallets.len:
            #Give equal amounts to each miner
            var amount: int = 100 div i

            #If this is the first miner, give them the remainder.
            if m == 0:
                amount += 100 mod i

            #Add the miner.
            miners.add(
                newMinerObj(
                    wallets[m].publicKey,
                    amount
                )
            )

        #Add a seq for the hashes.
        hashes.add(@[])
        #If Merit has been mined, create hashes (same amount as the nonce).
        if i != 1:
            for h in 0 ..< i:
                hashes[^1].add((char(i) & char(0) & char(h)).pad(48).toHash(384))
                if hashes[^1].len != 0:
                    verified[hashes[^1][^1].toString()] = @[]

        #Have the first miner verify everything instantly.
        for hash in hashes[^1]:
            #Create the Verification.
            var verif: MemoryVerification = newMemoryVerificationObj(hash)
            wallets[0].sign(verif, verifications[wallets[0].publicKey].height)
            verifications.add(verif)

            #Say this wallet verified this hash.
            verified[hash.toString()].add(wallets[0].publicKey)

        #Have the first half of the miners, except the first but plus the edge case, verify the hashes from 1 block ago.
        for w in 1 ..< (wallets.len div 2) + 1:
            for hash in hashes[^2]:
                #Don't verify anything we've already verified.
                if verified[hash.toString()].contains(wallets[w].publicKey):
                    continue

                #Create the Verification.
                var verif: MemoryVerification = newMemoryVerificationObj(hash)
                wallets[w].sign(verif, verifications[wallets[w].publicKey].height)
                verifications.add(verif)

                #Say this wallet verified this hash.
                verified[hash.toString()].add(wallets[w].publicKey)

        #Have the second half of the miners, plus the edge case, verify the hashes from 3 blocks ago.
        for w in (wallets.len div 2) - 1 ..< wallets.len:
            for hash in hashes[^4]:
                #Don't verify anything we've already verified.
                if verified[hash.toString()].contains(wallets[w].publicKey):
                    continue

                #Create the Verification.
                var verif: MemoryVerification = newMemoryVerificationObj(hash)
                wallets[w].sign(verif, verifications[wallets[w].publicKey].height)
                verifications.add(verif)

                #Say this wallet verified this hash.
                verified[hash.toString()].add(wallets[w].publicKey)

        #Create the new records.
        records.add(@[])
        for wallet in wallets:
            #Grab the Verifier.
            var verifier: BLSPublicKey = wallet.publicKey

            #Skip over Verifiers with no Verifications, if any manage to exist.
            if verifications[verifier].height == 0:
                continue

            #Continue if this user doesn't have unarchived Verifications.
            if verifications[verifier].verifications.len == 0:
                continue

            #Since there are unarchived verifications, add the VerifierRecord.
            var nonce: int = verifications[verifier].height - 1
            records[^1].add(newVerifierRecord(
                verifier,
                nonce,
                verifications[verifier].calculateMerkle(nonce)
            ))

        #Create the Block. We don't need to pass an aggregate signature because the blockchain doesn't test for that; MainMerit does.
        mining = newTestBlock(
            nonce = i,
            last = blockchain.tip.header.hash,
            records = records[^1],
            miners = miners
        )

        #Mine it.
        while not blockchain.difficulty.verify(mining.header.hash):
            inc(mining)

        #Add it to the Blockchain.
        try:
            blockchain.processBlock(mining)
        except ValueError as e:
            raise newException(ValueError, "Valid Block wasn't successfully added: " & e.msg)

        #Shift the records onto the Epochs.
        epoch = epochs.shift(verifications, records[^1])

        #Mark the records as archived.
        verifications.archive(records[^1])

        #Make sure the Epoch has the same hashes as we do.
        for hash in epoch.hashes.keys():
            assert(hashes[^6].contains(hash.toHash(384)))
        for hash in hashes[^6]:
            assert(epoch.hashes.hasKey(hash.toString()))

        #Make sure the Epoch has the same list of verifiers as we do.
        for hash in hashes[^6]:
            for verifier in epoch.hashes[hash.toString()]:
                assert(verified[hash.toString()].contains(verifier))
            for verifier in verified[hash.toString()]:
                assert(epoch.hashes[hash.toString()].contains(verifier))

        #Test that the saved records are accurate.
        for record in records[^11]:
            assert(db.get("merit_" & record.key.toString & "_epoch").fromBinary() == record.nonce)

    #Manually set Merit Holders because Epochs relies on the State to do that but we don't have one,
    var holders: string = ""
    for wallet in wallets:
        holders &= wallet.publicKey.toString()
    db.put("merit_holders", holders)

    #Reload the Epochs.
    echo "Reloading the Epochs..."
    epochs = newEpochs(db, verifications, blockchain)

    echo "Testing the reloaded Epochs..."

    #Shift 5 blank sets of records.
    for i in 0 ..< 5:
        epoch = epochs.shift(verifications, @[])

        #Make sure the Epoch has the same hashes as we do.
        for hash in epoch.hashes.keys():
            assert(hashes[^(5 - i)].contains(hash.toHash(384)))
        for hash in hashes[^(5 - i)]:
            assert(epoch.hashes.hasKey(hash.toString()))

        #Make sure the Epoch has the same list of verifiers as we do.
        for hash in hashes[^(5 - i)]:
            for verifier in epoch.hashes[hash.toString()]:
                assert(verified[hash.toString()].contains(verifier))
            for verifier in verified[hash.toString()]:
                assert(epoch.hashes[hash.toString()].contains(verifier))

    #Test that the saved records are accurate.
    for record in records[^6]:
        assert(db.get("merit_" & record.key.toString() & "_epoch").fromBinary() == record.nonce)

test(3)
test(9)
test(15)

echo "Finished the Database/Merit/Epochs DB Test."
