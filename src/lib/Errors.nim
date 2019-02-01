#Errors file for all custom error types we want to declare.

type
    #lib Errors.
    RandomError* = object of Exception #Used when the RNG fails.
    ArgonError*  = object of Exception #Used when Argon fails.
    BLSError*    = object of Exception #Used when BLS fails.
    SodiumError* = object of Exception #Used when LibSodium fails.
    EventError*    = object of Exception #Used when the EventEmiiter fails.

    #Database/common Errors.
    MerosIndexError* = object of Exception #KeyError, yet not `of ValueError`. It's prefixed with Meros since Nim provides an IndexError.

    #Database/Filesystem Errors.
    MemoryError* = object of Exception #Used when alloc/dealloc fails.

    #Database/Lattice Errors.
    MintError* = object of Exception #Used when Minting MR fails.

    #Network Errors.
    AsyncError*           = object of Exception #Used when async code fails.
    SocketError*          = object of Exception #Used when a socket fails.
    SyncConfigError*      = object of Exception #Used when a Socket which isn't set for syncing is used to sync.
    DataMissingError*     = object of Exception #Used when a Client is missing requested data.
    InvalidResponseError* = object of Exception #Used when a Client sends an Invalid Response.

    #UI/RPC Errors.
    ChannelError*  = object of Exception #Used when a Channel fails.
    PersonalError* = object of Exception #Used when the Wallet in the RPC fails.

    #UI/GUI Errors.
    WebViewError* = object of Exception #Used when Webview fails.
