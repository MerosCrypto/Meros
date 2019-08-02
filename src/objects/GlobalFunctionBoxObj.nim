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

#Element objects.
import ../Database/Consensus/objects/VerificationObj
import ../Database/Consensus/objects/MeritRemovalObj

#Difficulty, BlockHeader, and Block objects.
import ../Database/Merit/objects/DifficultyObj
import ../Database/Merit/objects/BlockHeaderObj
import ../Database/Merit/objects/BlockObj

#Difficulties and Transaction objects.
import ../Database/Transactions/objects/DifficultiesObj
import ../Database/Transactions/objects/TransactionObj
import ../Database/Transactions/objects/ClaimObj
import ../Database/Transactions/objects/SendObj
import ../Database/Transactions/objects/DataObj

#Message object.
import ../Network/objects/MessageObj

#Async lib.
import asyncdispatch

type
    SystemFunctionBox* = ref object
        quit*: proc () {.raises: [].}

    TransactionsFunctionBox* = ref object
        getDifficulties*: proc (): Difficulties {.raises: [].}

        getTransaction*: proc (
            hash: Hash[384]
        ): Transaction {.raises: [
            IndexError
        ].}

        addClaim*: proc (
            claim: Claim,
            syncing: bool = false
        ) {.raises: [
            ValueError,
            DataExists
        ].}

        addSend*: proc (
            send: Send,
            syncing: bool = false
        ) {.raises: [
            ValueError,
            DataExists
        ].}

        addData*: proc (
            data: Data,
            syncing: bool = false
        ) {.raises: [
            ValueError,
            DataExists
        ].}

    ConsensusFunctionBox* = ref object
        getHeight*: proc (
            key: BLSPublicKey
        ): int {.inline, raises: [].}

        getElement*: proc (
            key: BLSPublicKey,
            nonce: int
        ): Element {.raises: [
            IndexError
        ].}

        getUnarchivedRecords*: proc (): tuple[
            records: seq[MeritHolderRecord],
            aggregate: BLSSignature
        ] {.raises: [].}

        getPendingHashes*: proc (
            key: BLSPublicKey,
            nonce: int
        ): seq[Hash[384]] {.raises: [
            IndexError
        ].}

        addVerification*: proc (
            verif: Verification
        ) {.raises: [
            ValueError
        ].}

        addSignedVerification*: proc (
            verif: SignedVerification
        ) {.raises: [
            ValueError,
            GapError,
            DataExists
        ].}

        addMeritRemoval*: proc (
            mr: MeritRemoval
        ) {.raises: [].}

        addSignedMeritRemoval*: proc (
            mr: SignedMeritRemoval
        ) {.raises: [].}

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

        getTotalMerit*: proc (): int {.inline, raises: [].}

        getLiveMerit*: proc (): int {.inline, raises: [].}

        getMerit*: proc (
            key: BLSPublicKey
        ): int {.inline, raises: [].}

        addBlock*: proc (
            newBlock: Block,
            syncing: bool = false
        ): Future[void]

        addBlockByHeader*: proc (
            header: BlockHeader
        ): Future[void]

    PersonalFunctionBox* = ref object
        getMnemonic*: proc (): Mnemonic {.inline, raises: [].}

        setMnemonic*: proc (
            mnemonic: string,
            paassword: string
        ) {.raises: [
            ValueError
        ].}

        send*: proc (
            destination: string,
            amount: string
        ): Hash[384] {.raises: [
            ValueError,
            AddressError,
            NotEnoughMeros
        ].}

        data*: proc (
            data: string
        ): Hash[384] {.raises: [
            ValueError,
            DataExists
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
        transactions*: TransactionsFunctionBox
        consensus*:    ConsensusFunctionBox
        merit*:        MeritFunctionBox
        personal*:     PersonalFunctionBox
        network*:      NetworkFunctionBox

#Constructor.
func newGlobalFunctionBox*(): GlobalFunctionBox {.forceCheck: [].} =
    GlobalFunctionBox(
        system:       SystemFunctionBox(),
        transactions: TransactionsFunctionBox(),
        consensus:    ConsensusFunctionBox(),
        merit:        MeritFunctionBox(),
        personal:     PersonalFunctionBox(),
        network:      NetworkFunctionBox()
    )
