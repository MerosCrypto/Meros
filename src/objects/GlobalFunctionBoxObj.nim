discard """
This is a replacement for the previously used EventEmitters (mc_events).
It's type safe, and serves the same purpose, yet provides an even better API.
That said, we lose the library format, and instead have this.
This is annoying, but we no longer have to specify the type when we call events, so we break even.
"""

#Errors lib.
import ../lib/Errors

#Hash lib.
import ../lib/Hash

#MinerWallet and Wallet libs.
import ../Wallet/MinerWallet
import ../Wallet/Wallet

#LatticeIndex and VerifierRecord objects.
import ../Database/common/objects/LatticeIndexObj
import ../Database/common/objects/VerifierRecordObj

#Verification object.
import ../Database/Verifications/objects/VerificationObj

#Difficulty and Block objects.
import ../Database/Merit/objects/DifficultyObj
import ../Database/Merit/objects/BlockObj

#Lattice Entries.
import ../Database/Lattice/objects/EntryObj
import ../Database/Lattice/objects/ClaimObj
import ../Database/Lattice/objects/SendObj
import ../Database/Lattice/objects/ReceiveObj
import ../Database/Lattice/objects/DataObj

#Message object.
import ../Network/objects/MessageObj

#BN lib.
import BN

#Finals lib.
import finals

#Async lib.
import asyncdispatch

type
    SystemFunctionBox* = ref object
        quit*: proc () {.raises: [].}

    DatabaseFunctionBox* = ref object
        put*: proc (
            key: string,
            val: string
        ) {.raises: [
            DBWriteError
        ].}

        get*: proc (
            key: string
        ): string {.raises: [
            DBReadError
        ].}

        delete*: proc (
            key: string
        ) {.raises: [
            DBWriteError
        ].}

    VerificationsFunctionBox* = ref object
        getVerifierHeight*: proc (
            key: BLSPublicKey
        ): int {.raises: [].}

        getVerification*: proc (
            key: BLSPublicKey,
            nonce: int
        ): Verification {.raises: [
            IndexError
        ].}

        getUnarchivedRecords*: proc (): seq[VerifierRecord] {.raises: [
            IndexError
        ].}

        getPendingAggregate*: proc (
            key: BLSPublicKey,
            nonce: int
        ): BLSSignature {.raises: [
            IndexError,
            BLSError
        ].}

        getPendingHashes*: proc (
            key: BLSPublicKey,
            nonce: int
        ): seq[Hash[384]] {.raises: [
            IndexError
        ].}

        addVerification*: proc (
            verif: Verification
        ) {.raises: [
            ValueError,
            IndexError
        ].}

        addMemoryVerification*: proc (
            verif: MemoryVerification
        ) {.raises: [
            IndexError,
            ValueError,
            GapError,
            BLSError
        ].}

    MeritFunctionBox* = ref object
        getHeight*: proc (): int {.raises: [].}

        getDifficulty*: proc (): Difficulty {.raises: [].}

        getBlock*: proc (
            nonce: int
        ): Block {.raises: [
            IndexError
        ].}

        addBlock*: proc (
            newBlock: Block
        ): Future[bool]

    LatticeFunctionBox* = ref object
        getHeight*: proc (
            address: string
        ): int {.raises: [
            AddressError
        ].}

        getBalance*: proc (
            address: string
        ): BN {.raises: [
            AddressError
        ].}

        getEntryByHash*: proc (
            hash: Hash[384]
        ): Entry {.raises: [
            ValueError,
            IndexError,
            ArgonError,
            BLSError,
            EdPublicKeyError
        ].}

        getEntryByIndex*: proc (
            index: LatticeIndex
        ): Entry {.raises: [
            ValueError,
            IndexError
        ].}

        addClaim*: proc (
            claim: Claim
        ) {.raises: [
            ValueError,
            IndexError,
            GapError,
            AddressError,
            EdPublicKeyError,
            BLSError
        ].}

        addSend*: proc (
            send: Send
        ) {.raises: [
            ValueError,
            IndexError,
            GapError,
            AddressError,
            EdPublicKeyError,
            SodiumError
        ].}

        addReceive*: proc (
            recv: Receive
        ) {.raises: [
            ValueError,
            IndexError,
            GapError,
            AddressError,
            EdPublicKeyError
        ].}

        addData*: proc (
            data: Data
        ) {.raises: [
            ValueError,
            IndexError,
            GapError,
            AddressError,
            EdPublicKeyError
        ].}

    PersonalFunctionBox* = ref object
        getWallet*: proc (): Wallet {.raises: [].}

        setSeed*: proc (
            seed: string
        ) {.raises: [
            RandomError,
            EdSeedError,
            SodiumError
        ].}

        signSend*: proc (
            send: Send
        ) {.raises: [
            ValueError,
            AddressError,
            SodiumError
        ].}

        signReceive*: proc (
            recv: Receive
        ) {.raises: [
            SodiumError
        ].}

        signData*: proc (
            data: Data
        ) {.raises: [
            AddressError,
            SodiumError
        ].}

    NetworkFunctionBox* = ref object
        connect*: proc (
            ip: string,
            port: int
        ): Future[void]

        broadcast*: proc (
            msgType: MessageType,
            msg: string
        ): Future[void]

    GlobalFunctionBox* = ref object
        system*:        SystemFunctionBox
        database*:      DatabaseFunctionBox
        verifications*: VerificationsFunctionBox
        merit*:         MeritFunctionBox
        lattice*:       LatticeFunctionBox
        personal*:      PersonalFunctionBox
        network*:       NetworkFunctionBox

#Constructor.
func newGlobalFunctionBox*(): GlobalFunctionBox {.forceCheck: [].} =
    GlobalFunctionBox(
        system:        SystemFunctionBox(),
        database:      DatabaseFunctionBox(),
        verifications: VerificationsFunctionBox(),
        merit:         MeritFunctionBox(),
        lattice:       LatticeFunctionBox(),
        personal:      PersonalFunctionBox(),
        network:       NetworkFunctionBox()
    )
