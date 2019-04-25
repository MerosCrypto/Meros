#Errors lib, providing easy access to ForceCheck and defining all our custom errors.

#ForceCheck lib.
import ForceCheck
export ForceCheck

#Finals lib, imported so we can export its Error.
import finals
export FinalAttributeError

#DB lib, imported so we can export a masked LMDBerror.
import mc_lmdb

#Selectors standard lib, imported for an Error type asyncnet can raise but doesn't export.
import selectors
export IOSelectorsException

type
    #lib Errors.
    RandomError* = object of Exception #Used when the RNG fails.
    ArgonError*  = object of Exception #Used when the Argon library fails.

    #Wallet Errors.
    BLSError*         = object of Exception #Used when the BLS lib fails.
    SodiumError*      = object of Exception #Used when LibSodium fails.

    EdSeedError*      = object of Exception #Used when passed an invalid Ed25519 Seed.
    EdPublicKeyError* = object of Exception #Used when passed an invalid Ed25519 Public Key.
    AddressError*     = object of Exception #Used when passed an invalid Address.

    #Database/common Errors.
    GapError* = object of Exception #Used when trying to add an item, yet missing items before said item.

    #Database/Filesystem Errors.
    DBError*      = object of LMDBError
    DBWriteError* = object of DBError #Used when writing to the DB fails.
    DBReadError*  = object of DBError #Used when reading from the DB fails.

    #Database/Verifications Errors.
    MeritRemoval* = object of Exception #Used when a Verifier commits a malicious act against the network.

    #Database/Blockchain Errors.
    NotInEpochs* = object of Exception #Used when we try to add a Hash to Epochs and it's not already present in said Epochs.

    #Database/Lattice Errors.
    MintError* = object of Exception #Used when Minting MR fails.

    #Network Errors.
    SocketError*         = object of Exception #Used when a Socket fails.
    ClientError*         = object of Exception #Used when we try interacting with a disconnected Client or a Client who's breaking the protocol.
    InvalidMessageError* = object of Exception #Used when a Client follows the protocol, yet sends an improper message for the situation.
    SyncConfigError*     = object of Exception #Used when a Socket which isn't set for syncing is used to sync.
    DataMissing*         = object of Exception #Used when a Client is missing requested data.
    ValidityConcern*     = object of Exception #Used when the Network detects a potential Merit Removal or chain fork.

    #UI/GUI Errors.
    WebViewError* = object of Exception #Used when WebView fails.
    RPCError*     = object of Exception #Used when the GUI makes an invalid RPC call.
