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

#Difficulties and Entry objects.
import ../Database/Lattice/objects/DifficultiesObj
import ../Database/Lattice/objects/EntryObj
import ../Database/Lattice/objects/ClaimObj
import ../Database/Lattice/objects/SendObj
import ../Database/Lattice/objects/ReceiveObj
import ../Database/Lattice/objects/DataObj

#Message object.
import ../Network/objects/MessageObj

#BN lib.
import BN

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

        getUnarchivedRecords*: proc (): seq[VerifierRecord] {.raises: [].}

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
            IndexError,
            DataExists
        ].}

        addMemoryVerification*: proc (
            verif: MemoryVerification
        ) {.raises: [
            ValueError,
            IndexError,
            GapError,
            BLSError,
            DataExists
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
        ): Future[void]

    LatticeFunctionBox* = ref object
        getDifficulties*: proc (): Difficulties {.raises: [].}

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
            IndexError
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
            EdPublicKeyError
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
        ) {.raises: [].}

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
