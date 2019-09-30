#Errors objects, providing easy access to ForceCheck and defining all our custom errors.

#Hash object.
import ../Hash/objects/HashObj

#Element object.
import ../../Database/Consensus/Elements/objects/ElementObj

#ForceCheck lib.
import ForceCheck
export ForceCheck

#Finals lib, imported so we can export its Error.
import finals
export FinalAttributeError

#DB lib, imported so we can export a masked LMDBerror.
import mc_lmdb

#Selectors standard lib. Imported for an Error type asyncnet can raise but doesn't export.
import selectors
export IOSelectorsException

#JSON standard lib.
import json

type
    #lib Errors.
    RandomError* = object of Exception #Used when the RNG fails.

    #Wallet Errors.
    BLSError*         = object of Exception #Used when the BLS lib fails.
    EdPublicKeyError* = object of Exception #Used when passed an invalid Ed25519 Public Key.

    #Database/common Errors.
    GapError* = object of Exception #Used when trying to add an item, yet missing items before said item.

    #Database/common Statuses.
    DataExists* = object of Exception #Used when trying to add data which was already added.

    #Database/Filesystem Errors.
    DBError*     = LMDBError
    DBReadError* = object of DBError #Used when reading from the DB fails.

    #Database/Consensus Statuses.
    MaliciousMeritHolder* = object of Exception #Used when a MeritHolder commits a malicious act against the network.
        #MeritRemoval or pair Element, depending on where it's used in the codebase.
        element*: Element

    #Database/Merit Statuses.
    NotConnected* = object of Exception #Used when we test a BlockHeader we don't already have and it has a last which doesn't match our tip.
    NotInEpochs*  = object of Exception #Used when we try to add a Hash to Epochs and it's not already present in said Epochs.

    #Network Errors.
    SocketError*         = object of Exception #Used when a Socket fails.
    ClientError*         = object of Exception #Used when we try interacting with a disconnected Client or a Client who's breaking the protocol.
    InvalidMessageError* = object of Exception #Used when a Client follows the protocol, yet sends an improper message for the situation.
    SyncConfigError*     = object of Exception #Used when a Socket which isn't set for syncing is used to sync.

    #Network Statuses.
    DataMissing* = object of Exception #Used when a Client is missing requested data.
    Spam*        = object of Exception #Used when a Send/Data doesn't beat the difficulty.
        #Hash of the Transaction.
        hash*: Hash[384]
        #Argon hash.
        argon*: Hash[384]
    ValidityConcern* = object of Exception #Used when the Network detects a potential Merit Removal or chain fork.

    #Interfaces/RPC Errors.
    ParamError*   = object of Exception #Used when an invalid parameter is passed.
    JSONRPCError* = object of Exception #Used when the RPC call errors.
        code*: int
        data*: JSONNode

    #Interfaces/GUI Errors.
    WebViewError* = object of Exception #Used when WebView fails.
    RPCError*     = object of Exception #Used when the GUI makes an invalid RPC call.

    #Interfaces Statuses.
    NotEnoughMeros* = object of Exception #Used when the RPC is instructed to create a Send for more Meros than it can.
