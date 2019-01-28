discard """
This lib is special, in a few ways.
- It is prefixed by Main, and directly under src/, but it is NOT part of the include chain.
- It's not a lib, but an object file.
- It's named MainFunctions, but doesn't define a single function. Just prototypes.

This is a replacement for the previously used EventEmitters (mc_events).
It's type safe, and serves the same purpose, yet provides an even better API.
That said, we lose the library format, and instead have this.
This is annoying, but we no longer have to specify the type when we call events, so we break even.
"""

#BN lib.
import BN

#Wallet.
import Wallet/Wallet

#Verifications.
import Database/Verifications/Verifications

#Merit.
import Database/Merit/Merit

#Lattice.
import Database/Lattice/Lattice

#BLS lib.
import lib/BLS

#Finals lib.
import finals

finalsd:
    type
        SystemFunctionBox = ref object of RootObj
            quit* {.final.}: proc () {.raises: [ChannelError, AsyncError, SocketError].}

        VerificationsFunctionBox = ref object of RootObj
            getVerifierHeight*    {.final.}: proc (key: string): uint                           {.raises: [KeyError].}
            getVerification*      {.final.}: proc (key: string, nonce: uint): Verification      {.raises: [KeyError].}
            getUnarchivedIndexes* {.final.}: proc (): seq[VerifierIndex]                        {.raises: [KeyError, FinalAttributeError].}
            getPendingAggregate*  {.final.}: proc (verifier: string, nonce: uint): BLSSignature {.raises: [KeyError, BLSError].}
            getPendingHashes*     {.final.}: proc (key: string, nonce: uint): seq[string]       {.raises: [KeyError].}

            verification*       {.final.}: proc (verif: Verification): bool       {.raises: [ValueError].}
            memoryVerification* {.final.}: proc (verif: MemoryVerification): bool {.raises: [ValueError, BLSError].}

        MeritFunctionBox = ref object of RootObj
            getVerifierHeight*    {.final.}: proc (key: string): uint                           {.raises: [KeyError].}
            getVerification*      {.final.}: proc (key: string, nonce: uint): Verification      {.raises: [KeyError].}
            getUnarchivedIndexes* {.final.}: proc (): seq[VerifierIndex]                        {.raises: [KeyError, FinalAttributeError].}
            getPendingAggregate*  {.final.}: proc (verifier: string, nonce: uint): BLSSignature {.raises: [KeyError, BLSError].}
            getPendingHashes*     {.final.}: proc (key: string, nonceArg: uint): seq[string]    {.raises: [KeyError].}

            verification*        {.final.}: proc (verif: Verification): bool       {.raises: [ValueError].}
            memory_verification* {.final.}: proc (verif: MemoryVerification): bool {.raises: [ValueError, BLSError].}

        LatticeFunctionBox = ref object of RootObj
            getHeight*       {.final.}: proc (account: string): uint {.raises: [ValueError].}
            getBalance*      {.final.}: proc (account: string): BN   {.raises: [ValueError].}
            getEntryByHash*  {.final.}: proc (hash: string): Entry   {.raises: [KeyError, ValueError].}
            getEntryByIndex* {.final.}: proc (index: Index): Entry   {.raises: [ValueError].}

            claim*   {.final.}: proc (claim: Claim): bool  {.raises: [ValueError, AsyncError, BLSError, SodiumError].}
            send*    {.final.}: proc (send: Send): bool    {.raises: [ValueError, EventError, AsyncError, BLSError, SodiumError, FinalAttributeError].}
            receive* {.final.}: proc (recv: Receive): bool {.raises: [ValueError, AsyncError, BLSError, SodiumError].}
            data*    {.final.}: proc (data: Data): bool    {.raises: [ValueError, AsyncError, BLSError, SodiumError].}

        PersonalFunctionBox = ref object of RootObj
            getWallet* {.final.}: proc (): Wallet {.raises: [].}

            setSeed*     {.final.}: proc (seed: string)     {.raises: [ValueError, RandomError, SodiumError].}
            signSend*    {.final.}: proc (send: Send): bool {.raises: [ValueError, SodiumError, FinalAttributeError].}
            signReceive* {.final.}: proc (recv: Receive)    {.raises: [SodiumError, FinalAttributeError].}
            signData*    {.final.}: proc (data: Data): bool {.raises: [ValueError, SodiumError, FinalAttributeError].}

        NetworkFunctionBox = ref object of RootObj
            connect*   {.final.}: proc (ip: string, port: uint): Future[bool] {.async.}
            broadcast* {.final.}: proc (msgType: MessageType, msg: string)    {.raises: [AsyncError].}

        MainFunctionBox = ref object of RootObj
            system*        {.final.}: SystemFunctionBox
            verifications* {.final.}: VerificationsFunctionBox
            merit*         {.final.}: MeritFunctionBox
            lattice*       {.final.}: LatticeFunctionBox
            personal*      {.final.}: PersonalFunctionBox
            network*       {.final.}: NetworkFunctionBox

#Constructor.
proc newMainFunctionBox(): MainFunctionBox {.raises: [].} =
    MainFunctionBox(
        system:        SystemFunctionBox(),
        verifications: VerificationsFunctionBox(),
        merit:         MeritFunctionBox(),
        lattice:       LatticeFunctionBox(),
        personal:      PersonalFunctionBox(),
        network:       NetworkFunctionBox()
    )
