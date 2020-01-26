#Errors lib.
import ../../lib/Errors

#Util lib.
import ../../lib/Util

#GlobalFunctionBox object.
import ../../objects/GlobalFunctionBoxObj

#Peer lib.
import ../Peer

#Async standard lib.
import asyncdispatch

#SyncManager object.
type SyncManager* = ref object
    #Network ID.
    network: int
    #Protocol version.
    protocol: int
    #Services byte.
    services: char
    #Server port.
    port: int

    #Global Function Box.
    functions*: GlobalFunctionBox

#Constructor.
func newSyncManager*(
    network: int,
    protocol: int,
    port: int,
    functions: GlobalFunctionBox
): SyncManager {.forceCheck: [].} =
    SyncManager(
        network: network,
        protocol: protocol,
        port: port,
        functions: functions
    )

#Update the services byte.
func updateServices*(
    manager: SyncManager,
    service: uint8
) {.forceCheck: [].} =
    manager.services = char(uint8(manager.services) and service)

#Handle a new connection.
proc handle*(
    manager: SyncManager,
    peer: Peer
) {.forceCheck: [], async.} =
    discard
