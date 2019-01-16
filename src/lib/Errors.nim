#Errors file for all custom error types we want to declare.

type
    #lib Errors.
    RandomError*   = object of Exception #Used when the RNG fails.
    ArgonError*    = object of Exception #Used when Argon fails.
    BLSError*      = object of Exception #Used when BLS fails.
    SodiumError*   = object of Exception #Used when LibSodium fails.

    #Database/common Errors.
    EmbIndexError*    = object of Exception #KeyError, yet not `of ValueError`. It's prefixed with Emb since Nim provides an EmbIndexError.

    #Database/Filesystem Errors.
    MemoryError*   = object of Exception #Used when alloc/dealloc fails.

    #Database/Lattice Errors.
    MintError*     = object of Exception #Used when Minting EMB fails.

    #Network Errors.
    AsyncError*    = object of Exception #Used when async code fails.
    SocketError*   = object of Exception #Used when a socket fails.

    #UI/RPC Errors.
    ChannelError*  = object of Exception #Used when a Channel fails.
    PersonalError* = object of Exception #Used when the Wallet in the RPC fails.

    #UI/GUI Errors.
    WebViewError*  = object of Exception #Used when Webview fails.

    #External errors.
    EventError*    = object of Exception #Used when the EventEmiiter fails.
