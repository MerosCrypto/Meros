#[
This is a replacement for the previously used EventEmitters (mc_events).
It's type safe, and serves the same purpose, yet provides an even better API.
That said, we lose the library format, and instead have this.
This is annoying, but we no longer have to specify the type when we call events, so we break even.
]#

#Errors lib.
import ../lib/Errors

#Hash lib.
import ../lib/Hash

#Sketcher lib.
import ../lib/Sketcher

#MinerWallet and Wallet libs.
import ../Wallet/MinerWallet
import ../Wallet/Wallet

#Element lib and TransactionStatus object.
import ../Database/Consensus/objects/TransactionStatusObj
import ../Database/Consensus/Elements/Elements

#Difficulty, BlockHeader, and Block objects.
import ../Database/Merit/objects/DifficultyObj
import ../Database/Merit/objects/BlockHeaderObj
import ../Database/Merit/objects/BlockObj

#Transaction objects.
import ../Database/Transactions/objects/TransactionObj
import ../Database/Transactions/objects/ClaimObj
import ../Database/Transactions/objects/SendObj
import ../Database/Transactions/objects/DataObj

#Message and SketchyBlock objects.
import ../Network/objects/MessageObj
import ../Network/objects/SketchyBlockObj

#Async lib.
import asyncdispatch

type
    SystemFunctionBox* = ref object
        quit*: proc () {.raises: [].}

    TransactionsFunctionBox* = ref object
        getTransaction*: proc (
            hash: Hash[384]
        ): Transaction {.raises: [
            IndexError
        ].}

        getSpenders*: proc (
            input: Input
        ): seq[Hash[384]] {.inline, raises: [].}

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

        verify*: proc (
            hash: Hash[384]
        ) {.raises: [].}

        unverify*: proc (
            hash: Hash[384]
        ) {.raises: [].}

    ConsensusFunctionBox* = ref object
        getSendDifficulty*: proc (): Hash[384] {.inline, raises: [].}
        getDataMinimumDifficulty*: proc (): Hash[384] {.inline, raises: [].}
        getDataDifficulty*: proc (): Hash[384] {.inline, raises: [].}

        isMalicious*: proc (
            nick: uint16,
        ): bool {.inline, raises: [].}

        getStatus*: proc (
            hash: Hash[384]
        ): TransactionStatus {.raises: [
            IndexError
        ].}

        getThreshold*: proc (
            epoch: int
        ): int {.inline, raises: [].}

        getPending*: proc (): tuple[
            packets: seq[VerificationPacket],
            aggregate: BLSSignature
        ] {.inline, raises: [].}

        addVerificationPacket*: proc (
            packet: VerificationPacket
        ) {.raises: [].}

        addSignedVerification*: proc (
            verif: SignedVerification
        ) {.raises: [
            ValueError,
            DataExists
        ].}

        addSignedMeritRemoval*: proc (
            mr: SignedMeritRemoval
        ) {.raises: [
            ValueError
        ].}

    MeritFunctionBox* = ref object
        getHeight*: proc (): int {.inline, raises: [].}
        getTail*: proc (): Hash[384] {.inline, raises: [].}

        getBlockHashBefore*: proc (
            hash: Hash[384]
        ): Hash[384] {.raises: [
            IndexError
        ].}

        getBlockHashAfter*: proc (
            hash: Hash[384]
        ): Hash[384] {.raises: [
            IndexError
        ].}

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

        getPublicKey*: proc (
            nick: uint16
        ): BLSPublicKey {.raises: [
            IndexError
        ].}

        getNickname*: proc (
            key: BLSPublicKey
        ): uint16 {.raises: [
            IndexError
        ].}

        getTotalMerit*: proc (): int {.inline, raises: [].}
        getUnlockedMerit*: proc (): int {.inline, raises: [].}
        getMerit*: proc (
            nick: uint16
        ): int {.inline, raises: [].}

        isUnlocked*: proc (
            nick: uint16
        ): bool {.inline, raises: [].}

        addBlock*: proc (
            newBlock: SketchyBlock,
            sketcher: Sketcher,
            syncing: bool
        ): Future[void]

        addBlockByHeader*: proc (
            header: BlockHeader,
            syncing: bool
        ): Future[void]

        addBlockByHash*: proc (
            hash: Hash[384],
            syncing: bool
        ): Future[void]

        testBlockHeader*: proc (
            header: BlockHeader
        ) {.raises: [
            ValueError,
            NotConnected
        ].}

    PersonalFunctionBox* = ref object
        getWallet*: proc (): Wallet {.inline, raises: [].}

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
