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

#BlockHeader and Block objects.
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

#Chronos external lib.
import chronos

#Locks standard lib.
import locks

type
    SystemFunctionBox* = ref object
        quit*: proc () {.gcsafe, raises: [].}

    TransactionsFunctionBox* = ref object
        getTransaction*: proc (
            hash: Hash[256]
        ): Transaction {.gcsafe, raises: [
            IndexError
        ].}

        getUTXOs*: proc (
            key: EdPublicKey
        ): seq[FundedInput] {.gcsafe, raises: [].}

        getSpenders*: proc (
            input: Input
        ): seq[Hash[256]] {.gcsafe, raises: [].}

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
            hash: Hash[256]
        ) {.gcsafe, raises: [].}

        unverify*: proc (
            hash: Hash[256]
        ) {.gcsafe, raises: [].}

        beat*: proc (
            hash: Hash[256]
        ) {.gcsafe, raises: [].}

        discoverTree*: proc (
            hash: Hash[256]
        ): seq[Hash[256]] {.gcsafe, raises: [].}

        prune*: proc (
            hash: Hash[256]
        ) {.gcsafe, raises: [].}

    ConsensusFunctionBox* = ref object
        getSendDifficulty*: proc (): uint32 {.gcsafe, raises: [].}
        getDataDifficulty*: proc (): uint32 {.gcsafe, raises: [].}

        isMalicious*: proc (
            nick: uint16,
        ): bool {.gcsafe, raises: [].}

        getArchivedNonce*: proc (
            holder: uint16
        ): int {.gcsafe, raises: [].}

        hasArchivedPacket*: proc (
            hash: Hash[256]
        ): bool {.gcsafe, raises: [
            IndexError
        ].}

        getStatus*: proc (
            hash: Hash[256]
        ): TransactionStatus {.gcsafe, raises: [
            IndexError
        ].}

        getThreshold*: proc (
            epoch: int
        ): int {.gcsafe, raises: [].}

        getPending*: proc (): tuple[
            packets: seq[VerificationPacket],
            elements: seq[BlockElement],
            aggregate: BLSSignature
        ] {.gcsafe, raises: [].}

        addSignedVerification*: proc (
            verif: SignedVerification
        ) {.gcsafe, raises: [
            ValueError,
            DataExists
        ].}

        addVerificationPacket*: proc (
            packet: VerificationPacket
        ) {.gcsafe, raises: [].}

        addSendDifficulty*: proc (
            dataDiff: SendDifficulty
        ) {.gcsafe, raises: [].}

        addSignedSendDifficulty*: proc (
            dataDiff: SignedSendDifficulty
        ) {.gcsafe, raises: [
            ValueError,
            DataExists
        ].}

        addDataDifficulty*: proc (
            dataDiff: DataDifficulty
        ) {.gcsafe, raises: [].}

        addSignedDataDifficulty*: proc (
            dataDiff: SignedDataDifficulty
        ) {.gcsafe, raises: [
            ValueError,
            DataExists
        ].}

        verifyUnsignedMeritRemoval*: proc (
            mr: MeritRemoval
        ): Future[void] {.gcsafe.}

        addSignedMeritRemoval*: proc (
            mr: SignedMeritRemoval
        ): Future[void] {.gcsafe.}

    MeritFunctionBox* = ref object
        getHeight*: proc (): int {.gcsafe, raises: [].}
        getTail*: proc (): Hash[256] {.gcsafe, raises: [].}

        getRandomX*: proc (): RandomX {.gcsafe, raises: [].}
        getRandomXCacheKey*: proc (): string {.gcsafe, raises: [].}

        getBlockHashBefore*: proc (
            hash: Hash[256]
        ): Hash[256] {.gcsafe, raises: [
            IndexError
        ].}

        getBlockHashAfter*: proc (
            hash: Hash[256]
        ): Hash[256] {.gcsafe, raises: [
            IndexError
        ].}

        getDifficulty*: proc (): uint64 {.gcsafe, raises: [].}

        getBlockByNonce*: proc (
            nonce: int
        ): Block {.gcsafe, raises: [
            IndexError
        ].}

        getBlockByHash*: proc (
            hash: Hash[256]
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

        getTotalMerit*: proc (): int {.gcsafe, raises: [].}
        getUnlockedMerit*: proc (): int {.gcsafe, raises: [].}
        getMerit*: proc (
            nick: uint16,
            height: int
        ): int {.gcsafe, raises: [].}

        isUnlocked*: proc (
            nick: uint16
        ): bool {.gcsafe, raises: [].}

        addBlockInternal*: proc (
            newBlock: SketchyBlock,
            sketcher: Sketcher,
            syncing: bool,
            lock: ref Lock
        ): Future[void] {.gcsafe.}

        addBlock*: proc (
            newBlock: SketchyBlock,
            sketcher: Sketcher,
            syncing: bool
        ): Future[void] {.gcsafe.}

        addBlockByHeaderInternal*: proc (
            header: BlockHeader,
            syncing: bool,
            lock: ref Lock
        ): Future[void] {.gcsafe.}

        addBlockByHeader*: proc (
            header: BlockHeader,
            syncing: bool
        ): Future[void] {.gcsafe.}

        addBlockByHashInternal*: proc (
            hash: Hash[256],
            syncing: bool,
            lock: ref Lock
        ): Future[void] {.gcsafe.}

        addBlockByHash*: proc (
            peer: Peer,
            hash: Hash[256]
        ): Future[void] {.gcsafe.}

        testBlockHeader*: proc (
            header: BlockHeader
        ) {.gcsafe, raises: [
            ValueError
        ].}

    PersonalFunctionBox* = ref object
        getMinerWallet*: proc(): MinerWallet {.gcsafe, raises: [].}

        getWallet*: proc (): Wallet {.gcsafe, raises: [].}

        setMnemonic*: proc (
            mnemonic: string,
            paassword: string
        ) {.gcsafe, raises: [
            ValueError
        ].}

        send*: proc (
            destination: string,
            amount: string
        ): Hash[256] {.gcsafe, raises: [
            ValueError,
            NotEnoughMeros
        ].}

        data*: proc (
            data: string
        ): Hash[256] {.gcsafe, raises: [
            ValueError,
            DataExists
        ].}

    NetworkFunctionBox* = ref object
        connect*: proc (
            ip: string,
            port: int
        ): Future[void] {.gcsafe.}

        getPeers*: proc (): seq[Peer] {.gcsafe, raises: [].}

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
