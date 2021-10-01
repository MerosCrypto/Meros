import locks
import sets
import options

import chronos

import ../lib/[Errors, Hash]
import ../Wallet/[MinerWallet, Wallet]

import ../Database/Filesystem/Wallet/WalletDB

import ../Database/Merit/objects/[BlockHeaderObj, BlockObj]

import ../Database/Consensus/objects/TransactionStatusObj
import ../Database/Consensus/Elements/Elements

import ../Database/Transactions/objects/[
  TransactionObj,
  ClaimObj,
  SendObj,
  DataObj
]

import ../Network/objects/[
  MessageObj,
  PeerObj,
  SketchyBlockObj
]

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
      key: RistrettoPublicKey
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
    ): Future[void] {.gcsafe.}

    addData*: proc (
      data: Data,
      syncing: bool = false
    ): Future[void] {.gcsafe.}

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

    discoverUnorderedTree*: proc (
      hash: Hash[256],
      discovered: HashSet[Hash[256]]
    ): HashSet[Hash[256]] {.gcsafe, raises: [].}

    prune*: proc (
      hash: Hash[256]
    ) {.gcsafe, raises: [].}

  ConsensusFunctionBox* = ref object
    getSendDifficulty*: proc (): uint16 {.gcsafe, raises: [].}
    getSendDifficultyOfHolder*: proc (
      holder: uint16
    ): uint16 {.gcsafe, raises: [
      IndexError
    ].}

    getDataDifficulty*: proc (): uint16 {.gcsafe, raises: [].}
    getDataDifficultyOfHolder*: proc (
      holder: uint16
    ): uint16 {.gcsafe, raises: [
      IndexError
    ].}

    isMalicious*: proc (
      nick: uint16,
    ): bool {.gcsafe, raises: [].}

    getArchivedNonce*: proc (
      holder: uint16
    ): int {.gcsafe, raises: [].}

    hasArchivedPacket*: proc (
      hash: Hash[256]
    ): bool {.gcsafe, raises: [].}

    getStatus*: proc (
      hash: Hash[256]
    ): TransactionStatus {.gcsafe, raises: [
      IndexError
    ].}

    getThreshold*: proc (
      epoch: int
    ): int {.gcsafe, raises: [].}

    getElement*: proc (
      holder: uint16,
      nonce: int
    ): BlockElement {.gcsafe, raises: [
      IndexError
    ].}

    getPending*: proc (): tuple[
      packets: seq[VerificationPacket],
      elements: seq[BlockElement],
      aggregate: BLSSignature
    ] {.gcsafe, raises: [].}

    addSignedVerification*: proc (
      verif: SignedVerification
    ): Future[void] {.gcsafe.}

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

    getRawMerit*: proc (
      nick: uint16
    ): int {.gcsafe, raises: [].}

    getMerit*: proc (
      nick: uint16,
      height: int
    ): int {.gcsafe, raises: [].}

    isUnlocked*: proc (
      nick: uint16
    ): bool {.gcsafe, raises: [].}

    isPending*: proc (
      nick: uint16
    ): bool {.gcsafe, raises: [].}

    isRegisterable*: proc (
      inputs: seq[Input]
    ): bool {.gcsafe, raises: [].}

    addBlockInternal*: proc (
      newBlock: SketchyBlock,
      sketcher: seq[VerificationPacket],
      syncing: bool,
      lock: ref Lock
    ): Future[void] {.gcsafe.}

    addBlock*: proc (
      newBlock: SketchyBlock,
      sketcher: seq[VerificationPacket],
      syncing: bool
    ): Future[void] {.gcsafe.}

    addBlockByHeaderInternal*: proc (
      sketchyHeader: BlockHeader,
      syncing: bool,
      lock: ref Lock
    ): Future[void] {.gcsafe.}

    addBlockByHeader*: proc (
      sketchyHeader: BlockHeader,
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
    getMinerWallet*: proc(): MinerWallet {.gcsafe, raises: [
      ValueError
    ].}

    getMnemonic*: proc (): string {.gcsafe, raises: [
      ValueError
    ].}

    getAccount*: proc (): tuple[key: RistrettoPublicKey, chainCode: Hash[256]] {.gcsafe, raises: [].}

    setAccount*: proc (
      key: RistrettoPublicKey,
      chainCode: Hash[256],
      clear: bool = false
    ) {.gcsafe, raises: [].}

    setWallet*: proc (
      mnemonic: string,
      password: string
    ) {.gcsafe, raises: [
      ValueError
    ].}

    getAddress*: proc (
      index: Option[uint32]
    ): string {.gcsafe, raises: [
      ValueError
    ].}

    getChangeKey*: proc (): RistrettoPublicKey {.gcsafe, raises: [].}

    getKeyIndex*: proc (
      key: RistrettoPublicKey
    ): KeyIndex {.gcsafe, raises: [
      IndexError
    ].}

    sign*: proc (
      send: Send,
      keys: seq[KeyIndex],
      password: string
    ) {.gcsafe, raises: [
      IndexError,
      ValueError
    ].}

    data*: proc (
      data: string,
      password: string
    ): Future[Hash[256]] {.gcsafe.}

    getUTXOs*: proc (): seq[UsableInput] {.gcsafe, raises: [].}

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

func newGlobalFunctionBox*(): GlobalFunctionBox {.forceCheck: [].} =
  GlobalFunctionBox(
    system:       SystemFunctionBox(),
    transactions: TransactionsFunctionBox(),
    consensus:    ConsensusFunctionBox(),
    merit:        MeritFunctionBox(),
    personal:     PersonalFunctionBox(),
    network:      NetworkFunctionBox()
  )
