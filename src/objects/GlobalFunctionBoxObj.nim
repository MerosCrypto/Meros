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

#MeritHolderRecord object.
import ../Database/common/objects/MeritHolderRecordObj

#Verification object.
import ../Database/Consensus/objects/VerificationObj

#Difficulty, BlockHeader, and Block objects.
import ../Database/Merit/objects/DifficultyObj
import ../Database/Merit/objects/BlockHeaderObj
import ../Database/Merit/objects/BlockObj

#Difficulties and Transaction objects.
import ../Database/Transactions/objects/DifficultiesObj
import ../Database/Transactions/objects/TransactionObj
import ../Database/Transactions/objects/ClaimObj
import ../Database/Transactions/objects/SendObj
import ../Database/Transactions/objects/ReceiveObj
import ../Database/Transactions/objects/DataObj

#Message object.
import ../Network/objects/MessageObj

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

    ConsensusFunctionBox* = ref object
        getMeritHolderHeight*: proc (
            key: BLSPublicKey
        ): int {.inline, raises: [].}

        getElement*: proc (
            key: BLSPublicKey,
            nonce: int
        ): Verification {.raises: [
            IndexError
        ].}

        getUnarchivedRecords*: proc (): seq[MeritHolderRecord] {.raises: [].}

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

        addSignedVerification*: proc (
            verif: SignedVerification
        ) {.raises: [
            ValueError,
            IndexError,
            GapError,
            BLSError,
            DataExists
        ].}

    MeritFunctionBox* = ref object
        getHeight*: proc (): int {.inline, raises: [].}

        getDifficulty*: proc (): Difficulty {.inline, raises: [].}

        getBlockByNonce*: proc (
            nonce: int
        ): Block {.raises: [
            IndexError
        ].}

        getBlockByHash*: proc (
            hash: Hash[384]
        ): Block {.raises: [
            IndexError
        ].}

        addBlock*: proc (
            newBlock: Block
        ): Future[void]

        addBlockByHeader*: proc (
            header: BlockHeader
        ): Future[void]

    TransactionsFunctionBox* = ref object
        getDifficulties*: proc (): Difficulties {.raises: [].}

        getHeight*: proc (
            address: string
        ): int {.raises: [
            AddressError
        ].}

        getBalance*: proc (
            address: string
        ): uint64 {.raises: [
            AddressError
        ].}

        getTransaction*: proc (
            hash: Hash[384]
        ): Transaction {.raises: [
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
            BLSError,
            DataExists
        ].}

        addSend*: proc (
            send: Send
        ) {.raises: [
            ValueError,
            IndexError,
            GapError,
            AddressError,
            EdPublicKeyError,
            DataExists
        ].}

        addReceive*: proc (
            recv: Receive
        ) {.raises: [
            ValueError,
            IndexError,
            GapError,
            AddressError,
            EdPublicKeyError,
            DataExists
        ].}

        addData*: proc (
            data: Data
        ) {.raises: [
            ValueError,
            IndexError,
            GapError,
            AddressError,
            EdPublicKeyError,
            DataExists
        ].}

    PersonalFunctionBox* = ref object
        getWallet*: proc (): Wallet {.inline, raises: [].}

        setSecret*: proc (
            secret: string
        ) {.raises: [
            ValueError,
            RandomError
        ].}

        signSend*: proc (
            send: Send
        ) {.raises: [
            AddressError
        ].}

        signReceive*: proc (
            recv: Receive
        ) {.raises: [].}

        signData*: proc (
            data: Data
        ) {.raises: [
            AddressError
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
        system*:       SystemFunctionBox
        database*:     DatabaseFunctionBox
        consensus*:    ConsensusFunctionBox
        merit*:        MeritFunctionBox
        transactions*: TransactionsFunctionBox
        personal*:     PersonalFunctionBox
        network*:      NetworkFunctionBox

#Constructor.
func newGlobalFunctionBox*(): GlobalFunctionBox {.forceCheck: [].} =
    GlobalFunctionBox(
        system:       SystemFunctionBox(),
        database:     DatabaseFunctionBox(),
        consensus:    ConsensusFunctionBox(),
        merit:        MeritFunctionBox(),
        transactions: TransactionsFunctionBox(),
        personal:     PersonalFunctionBox(),
        network:      NetworkFunctionBox()
    )
