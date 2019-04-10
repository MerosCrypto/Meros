discard """
This is a replacement for the previously used EventEmitters (mc_events).
It's type safe, and serves the same purpose, yet provides an even better API.
That said, we lose the library format, and instead have this.
This is annoying, but we no longer have to specify the type when we call events, so we break even.
"""

#Errors lib.
import ../lib/Errors

#Message object.
import ../Network/objects/MessageObj

#MinerWallet and Wallet libs.
import ../Wallet/MinerWallet
import ../Wallet/Wallet

#VerifierIndex object.
import ../Database/common/objects/VerifierIndexObj

#Verification object.
import ../Database/Verifications/objects/VerificationObj

#Block object.
import ../Database/Merit/objects/BlockObj

#Lattice Entries.
import ../Database/Lattice/objects/EntryObj
import ../Database/Lattice/objects/ClaimObj
import ../Database/Lattice/objects/SendObj
import ../Database/Lattice/objects/ReceiveObj
import ../Database/Lattice/objects/DataObj

#BN lib.
import BN

#Finals lib.
import finals

#Async lib.
import asyncdispatch

type
    SystemFunctionBox* = ref object of RootObj
        quit*: proc () {.noSideEffect, raises: [ChannelError, AsyncError, SocketError].}

    VerificationsFunctionBox* = ref object of RootObj
        getVerifierHeight*:     proc (key: string): uint                           {.noSideEffect, raises: [KeyError, DBError].}
        getVerification*:       proc (key: string, nonce: uint): Verification      {.noSideEffect, raises: [KeyError, ValueError, BLSError, DBError, FinalAttributeError].}
        getUnarchivedIndexes*:  proc (): seq[VerifierIndex]                        {.noSideEffect, raises: [KeyError, ValueError, DBError, FinalAttributeError].}
        getPendingAggregate*:   proc (verifier: string, nonce: uint): BLSSignature {.noSideEffect, raises: [KeyError, ValueError, BLSError, DBError, FinalAttributeError].}
        getPendingHashes*:      proc (key: string, nonce: uint): seq[string]       {.noSideEffect, raises: [KeyError, ValueError, BLSError, DBError, FinalAttributeError].}

        addVerification*:        proc (verif: Verification): bool       {.noSideEffect, raises: [ValueError, DBError].}
        addMemoryVerification*:  proc (verif: MemoryVerification): bool {.noSideEffect, raises: [ValueError, BLSError, DBError].}

    MeritFunctionBox* = ref object of RootObj
        getHeight*:      proc (): uint             {.noSideEffect, raises: [DBError].}
        getDifficulty*:  proc (): BN               {.noSideEffect, raises: [].}
        getBlock*:       proc (nonce: uint): Block {.noSideEffect, raises: [ValueError, ArgonError, BLSError, DBError, FinalAttributeError].}

        addBlock*:  proc (newBlock: Block): Future[bool]

    LatticeFunctionBox* = ref object of RootObj
        getHeight*:        proc (account: string): uint {.noSideEffect, raises: [ValueError, DBError].}
        getBalance*:       proc (account: string): BN   {.noSideEffect, raises: [ValueError, DBError].}
        getEntryByHash*:   proc (hash: string): Entry   {.noSideEffect, raises: [KeyError].}
        getEntryByIndex*:  proc (index: Index): Entry   {.noSideEffect, raises: [ValueError].}

        addClaim*:    proc (claim: Claim): bool  {.noSideEffect, raises: [ValueError, AsyncError, BLSError, SodiumError, DBError].}
        addSend*:     proc (send: Send): bool    {.noSideEffect, raises: [ValueError, AsyncError, BLSError, SodiumError, DBError, FinalAttributeError].}
        addReceive*:  proc (recv: Receive): bool {.noSideEffect, raises: [ValueError, AsyncError, BLSError, DBError, SodiumError].}
        addData*:     proc (data: Data): bool    {.noSideEffect, raises: [ValueError, AsyncError, BLSError, DBError, SodiumError].}

    DatabaseFunctionBox* = ref object of RootObj
        put*:    proc (key: string, val: string) {.raises: [DBWriteError].}
        get*:    proc (key: string): string      {.raises: [DBReadError].}
        delete*: proc (key: string)              {.raises: [DBWriteError].}

    PersonalFunctionBox* = ref object of RootObj
        getWallet*:  proc (): Wallet {.noSideEffect, raises: [].}

        setSeed*:      proc (seed: string)  {.noSideEffect, raises: [ValueError, RandomError, SodiumError].}
        signSend*:     proc (send: Send)    {.noSideEffect, raises: [ValueError, SodiumError, FinalAttributeError].}
        signReceive*:  proc (recv: Receive) {.noSideEffect, raises: [SodiumError, FinalAttributeError].}
        signData*:     proc (data: Data)    {.noSideEffect, raises: [ValueError, SodiumError, FinalAttributeError].}

    NetworkFunctionBox* = ref object of RootObj
        connect*:    proc (ip: string, port: uint): Future[bool]
        broadcast*:  proc (msgType: MessageType, msg: string): Future[void]

    GlobalFunctionBox* = ref object of RootObj
        system*:         SystemFunctionBox
        verifications*:  VerificationsFunctionBox
        merit*:          MeritFunctionBox
        lattice*:        LatticeFunctionBox
        database*:       DatabaseFunctionBox
        personal*:       PersonalFunctionBox
        network*:        NetworkFunctionBox

#Constructor.
func newGlobalFunctionBox*(): GlobalFunctionBox {.forceCheck: [].} =
    GlobalFunctionBox(
        system:        SystemFunctionBox(),
        verifications: VerificationsFunctionBox(),
        merit:         MeritFunctionBox(),
        lattice:       LatticeFunctionBox(),
        database:      DatabaseFunctionBox(),
        personal:      PersonalFunctionBox(),
        network:       NetworkFunctionBox()
    )
