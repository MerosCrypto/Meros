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

#Network objects.
import ../Network/objects/MessageObj
import ../Network/objects/PeerObj
import ../Network/objects/SketchyBlockObj

#Locks standard lib.
import locks

#Async lib.
import asyncdispatch

type
    SystemFunctionBox* = ref object
        quit*: proc () {.raises: [].}

    TransactionsFunctionBox* = ref object
        getTransaction*: proc (
            hash: Hash[256]
        ): Transaction {.raises: [
            IndexError
        ].}

        getUTXOs*: proc (
            key: EdPublicKey
        ): seq[FundedInput] {.inline, raises: [].}

        getSpenders*: proc (
            input: Input
        ): seq[Hash[256]] {.inline, raises: [].}

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
            hash: Hash[256]
        ) {.inline, raises: [].}

        unverify*: proc (
            hash: Hash[256]
        ) {.inline, raises: [].}

        beat*: proc (
            hash: Hash[256]
        ) {.inline, raises: [].}

        discoverTree*: proc (
            hash: Hash[256]
        ): seq[Hash[256]] {.inline, raises: [].}

        prune*: proc (
            hash: Hash[256]
        ) {.inline, raises: [].}

    ConsensusFunctionBox* = ref object
        getSendDifficulty*: proc (): Hash[256] {.inline, raises: [].}
        getDataDifficulty*: proc (): Hash[256] {.inline, raises: [].}

        isMalicious*: proc (
            nick: uint16,
        ): bool {.inline, raises: [].}

        getArchivedNonce*: proc (
            holder: uint16
        ): int {.inline, raises: [].}

        hasArchivedPacket*: proc (
            hash: Hash[256]
        ): bool {.raises: [
            IndexError
        ].}

        getStatus*: proc (
            hash: Hash[256]
        ): TransactionStatus {.raises: [
            IndexError
        ].}

        getThreshold*: proc (
            epoch: int
        ): int {.inline, raises: [].}

        getPending*: proc (): tuple[
            packets: seq[VerificationPacket],
            elements: seq[BlockElement],
            aggregate: BLSSignature
        ] {.raises: [].}

        addSignedVerification*: proc (
            verif: SignedVerification
        ) {.raises: [
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
            ValueError,
            DataExists
        ].}

        addDataDifficulty*: proc (
            dataDiff: DataDifficulty
        ) {.raises: [].}

        addSignedDataDifficulty*: proc (
            dataDiff: SignedDataDifficulty
        ) {.raises: [
            ValueError,
            DataExists
        ].}

        verifyUnsignedMeritRemoval*: proc (
            mr: MeritRemoval
        ): Future[void]

        addSignedMeritRemoval*: proc (
            mr: SignedMeritRemoval
        ): Future[void]

    MeritFunctionBox* = ref object
        getHeight*: proc (): int {.inline, raises: [].}
        getTail*: proc (): Hash[256] {.inline, raises: [].}

        getRandomXCacheKey*: proc (): string {.inline, raises: [].}

        getBlockHashBefore*: proc (
            hash: Hash[256]
        ): Hash[256] {.raises: [
            IndexError
        ].}

        getBlockHashAfter*: proc (
            hash: Hash[256]
        ): Hash[256] {.raises: [
            IndexError
        ].}

        getDifficulty*: proc (): Difficulty {.inline, raises: [].}

        getBlockByNonce*: proc (
            nonce: int
        ): Block {.raises: [
            IndexError
        ].}

        getBlockByHash*: proc (
            hash: Hash[256]
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
            nick: uint16,
            height: int
        ): int {.inline, raises: [].}

        isUnlocked*: proc (
            nick: uint16
        ): bool {.inline, raises: [].}

        addBlockInternal*: proc (
            newBlock: SketchyBlock,
            sketcher: Sketcher,
            syncing: bool,
            lock: ref Lock
        ): Future[void]

        addBlock*: proc (
            newBlock: SketchyBlock,
            sketcher: Sketcher,
            syncing: bool
        ): Future[void]

        addBlockByHeaderInternal*: proc (
            header: BlockHeader,
            syncing: bool,
            lock: ref Lock
        ): Future[void]

        addBlockByHeader*: proc (
            header: BlockHeader,
            syncing: bool
        ): Future[void]

        addBlockByHashInternal*: proc (
            hash: Hash[256],
            syncing: bool,
            lock: ref Lock
        ): Future[void]

        addBlockByHash*: proc (
            peer: Peer,
            hash: Hash[256]
        ): Future[void]

        testBlockHeader*: proc (
            header: BlockHeader
        ) {.raises: [
            ValueError
        ].}

    PersonalFunctionBox* = ref object
        getMinerWallet*: proc(): MinerWallet {.inline, raises: [].}

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
        ): Hash[256] {.raises: [
            ValueError,
            NotEnoughMeros
        ].}

        data*: proc (
            data: string
        ): Hash[256] {.raises: [
            ValueError,
            DataExists
        ].}

    NetworkFunctionBox* = ref object
        connect*: proc (
            ip: string,
            port: int
        ): Future[void]

        getPeers*: proc (): seq[Peer] {.inline, raises: [].}

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
