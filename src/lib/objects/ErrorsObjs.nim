#Errors objects, providing easy access to ForceCheck and defining all our custom errors.

#Hash object.
import ../Hash/objects/HashObj

#Element object.
import ../../Database/Consensus/Elements/objects/ElementObj

#ForceCheck lib.
import ForceCheck
export ForceCheck

#mc_bls lib. Imported so we can export its error.
import mc_bls
export BLSError

#DB lib, imported so we can export a masked LMDBerror.
import mc_lmdb

#JSON standard lib.
import json

type
    #Compile-time Exception used when Meros is being built for an unsupported target.
    UnsupportedTarget* = object of Exception

    #lib Errors.
    RandomError* = object of CatchableError #Used when the RNG fails.
    SaltError*   = object of CatchableError #Used when a sketch salt causes a collision.

    #Database/common Statuses.
    DataMissing* = object of CatchableError #Used when data is missing. Also used by Network for the same reason.
    DataExists* = object of CatchableError #Used when trying to add data which was already added.

    #Database/Filesystem Errors.
    DBError*     = LMDBError
    DBReadError* = object of DBError #Used when reading from the DB fails.

    #Database/Consensus Statuses.
    MaliciousMeritHolder* = object of CatchableError #Used when a MeritHolder commits a malicious act against the network.
        #MeritRemoval or pair Element, depending on where it's used in the codebase.
        element*: Element

    #Database/Merit Statuses.
    NotInEpochs*  = object of CatchableError #Used when we try to add a Hash to Epochs and it's not already present in said Epochs.

    #Network Errors.
    SocketError* = object of CatchableError #Used when a socket breaks.
    PeerError*   = object of CatchableError #Used when a Peer breaks protocol.

    #Network Statuses.
    Spam* = object of CatchableError #Used when a Send/Data doesn't beat the difficulty.
        #Hash of the Transaction.
        hash*: Hash[256]
        #Argon hash.
        argon*: Hash[256]
        #Difficulty the argon was multiplied by.
        difficulty*: uint32

    #Interfaces/RPC Errors.
    ParamError*   = object of CatchableError #Used when an invalid parameter is passed.
    JSONRPCError* = object of CatchableError #Used when the RPC call errors.
        code*: int
        data*: JSONNode

    #Interfaces/GUI Errors.
    WebViewError* = object of CatchableError #Used when WebView fails.
    RPCError*     = object of CatchableError #Used when the GUI makes an invalid RPC call.

    #Interfaces Statuses.
    NotEnoughMeros* = object of CatchableError #Used when the RPC is instructed to create a Send for more Meros than it can.
