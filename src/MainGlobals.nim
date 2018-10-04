include MainImports

#Constants. This acts as a sort-of chain params.
const
    NETWORK_ID: int = 0
    PROTOCOL: int = 0

#Global variables used throught Main.
var
    events: EventEmitter = newEventEmitter() #EventEmitter for queries and new data.

    #Lattice.
    lattice: Lattice = newLattice()          #Lattice.
    genesisSend: Index                       #Genesis Send. Puts the first coins on the network.

    #Network.
    network: Network                         #Network.

    #UI.
    ui: UI                                   #RPC and GUI.

#Handle node level events.
#Properly shutdown.
events.on(
    "system.quit",
    proc () {.raises: [Exception].} =
        #Shut down the UI.
        ui.shutdown()

        #Shut down the Network.
        network.shutdown()

        #Quit.
        quit(0)
)
