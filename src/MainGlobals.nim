include MainConstants

#Global variables used throught Main.
var
    events: EventEmitter = newEventEmitter() #EventEmitter for queries and new data.

    #Merit.
    merit: Merit                             #Blockchain and state.

    #Lattice.
    lattice: Lattice                         #Lattice.
    genesisSend: Index                       #Genesis Send. Puts the first coins on the network.

    #Network.
    network: Network                         #Network.

    #UI.
    ui: UI                                   #RPC and GUI.

#Handle node level events.

#Properly shutdown.
events.on(
    "system.quit",
    proc () {.raises: [ChannelError, SocketError].} =
        #Shut down the UI.
        ui.shutdown()

        #Shut down the Network.
        network.shutdown()

        #The GUI checks to shut down every 100 seconds. 200 is a safety measure.
        sleep(200)

        #Quit.
        quit(0)
)
