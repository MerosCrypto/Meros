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
        quit*: proc () {.gcsafe, raises: [].}

    TransactionsFunctionBox* = ref object
        getTransaction*: proc (
            hash: Hash[384]
        ): Transaction {.gcsafe, raises: [
            IndexError
        ].}

        getSpenders*: proc (
            input: Input
        ): seq[Hash[384]] {.inline, gcsafe, raises: [].}

        addClaim*: proc (
            claim: Claim,
            syncing: bool = false
        ) {.gcsafe, raises: [
            ValueError,
            DataExists
        ].}

        addSend*: proc (
            send: Send,
            syncing: bool = false
        ) {.gcsafe, raises: [
            ValueError,
            DataExists
        ].}

        addData*: proc (
            data: Data,
            syncing: bool = false
        ) {.gcsafe, raises: [
            ValueError,
            DataExists
        ].}

        verify*: proc (
            hash: Hash[384]
        ) {.gcsafe, raises: [].}

        unverify*: proc (
            hash: Hash[384]
        ) {.gcsafe, raises: [].}

    ConsensusFunctionBox* = ref object
        getSendDifficulty*: proc (): Hash[384] {.inline, gcsafe, raises: [].}
        getDataMinimumDifficulty*: proc (): Hash[384] {.inline, raises: [].}
        getDataDifficulty*: proc (): Hash[384] {.inline, gcsafe, raises: [].}

        isMalicious*: proc (
            nick: uint16,
        ): bool {.inline, gcsafe, raises: [].}

        getNonce*: proc (
            holder: uint16
        ): int {.inline, raises: [].}

        hasArchivedPacket*: proc (
            hash: Hash[384]
        ): bool {.gcsafe, raises: [
            IndexError
        ].}

        getStatus*: proc (
            hash: Hash[384]
        ): TransactionStatus {.gcsafe, raises: [
            IndexError
        ].}

        getThreshold*: proc (
            epoch: int
        ): int {.gcsafe, inline, raises: [].}

        getPending*: proc (): tuple[
            packets: seq[VerificationPacket],
            aggregate: BLSSignature
        ] {.gcsafe, inline, raises: [].}

        addSignedVerification*: proc (
            verif: SignedVerification
        ) {.gcsafe, raises: [
            ValueError,
            DataExists
        ].}

        addVerificationPacket*: proc (
            packet: VerificationPacket
        ) {.raises: [].}

        addSendDifficulty*: proc (
            dataDiff: SendDifficulty
        ) {.raises: [].}

        addSignedSendDifficulty*: proc (
            dataDiff: SignedSendDifficulty
        ) {.raises: [
            ValueError
        ].}

        addDataDifficulty*: proc (
            dataDiff: DataDifficulty
        ) {.raises: [].}

        addSignedDataDifficulty*: proc (
            dataDiff: SignedDataDifficulty
        ) {.raises: [
            ValueError
        ].}

        addSignedMeritRemoval*: proc (
            mr: SignedMeritRemoval
        ) {.gcsafe, raises: [
            ValueError
        ].}

    MeritFunctionBox* = ref object
        getHeight*: proc (): int {.inline, gcsafe, raises: [].}
        getTail*: proc (): Hash[384] {.inline, gcsafe, raises: [].}

        getBlockHashBefore*: proc (
            hash: Hash[384]
        ): Hash[384] {.gcsafe, raises: [
            IndexError
        ].}

        getBlockHashAfter*: proc (
            hash: Hash[384]
        ): Hash[384] {.gcsafe, raises: [
            IndexError
        ].}

        getDifficulty*: proc (): Difficulty {.inline, gcsafe, raises: [].}

        getBlockByNonce*: proc (
            nonce: int
        ): Block {.gcsafe, raises: [
            IndexError
        ].}

        getBlockByHash*: proc (
            hash: Hash[384]
        ): Block {.gcsafe, raises: [
            IndexError
        ].}

        getPublicKey*: proc (
            nick: uint16
        ): BLSPublicKey {.gcsafe, raises: [
            IndexError
        ].}

        getNickname*: proc (
            key: BLSPublicKey
        ): uint16 {.gcsafe, raises: [
            IndexError
        ].}

        getTotalMerit*: proc (): int {.inline, gcsafe, raises: [].}
        getUnlockedMerit*: proc (): int {.inline, gcsafe, raises: [].}
        getMerit*: proc (
            nick: uint16
        ): int {.inline, gcsafe, raises: [].}

        isUnlocked*: proc (
            nick: uint16
        ): bool {.inline, gcsafe, raises: [].}

        addBlock*: proc (
            newBlock: SketchyBlock,
            sketcher: Sketcher,
            syncing: bool
        ): Future[void] {.gcsafe.}

        addBlockByHeader*: proc (
            header: BlockHeader,
            syncing: bool
        ): Future[void] {.gcsafe.}

        addBlockByHash*: proc (
            hash: Hash[384],
            syncing: bool
        ): Future[void] {.gcsafe.}

        testBlockHeader*: proc (
            header: BlockHeader
        ) {.gcsafe, raises: [
            ValueError,
            NotConnected
        ].}

    PersonalFunctionBox* = ref object
        getWallet*: proc (): Wallet {.inline, gcsafe, raises: [].}

        setMnemonic*: proc (
            mnemonic: string,
            paassword: string
        ) {.gcsafe, raises: [
            ValueError
        ].}

        send*: proc (
            destination: string,
            amount: string
        ): Hash[384] {.gcsafe, raises: [
            ValueError,
            NotEnoughMeros
        ].}

        data*: proc (
            data: string
        ): Hash[384] {.gcsafe, raises: [
            ValueError,
            DataExists
        ].}

    NetworkFunctionBox* = ref object
        connect*: proc (
            ip: string,
            port: int
        ): Future[void] {.gcsafe.}

        broadcast*: proc (
            msgType: MessageType,
            msg: string
        ) {.gcsafe, raises: [].}

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
