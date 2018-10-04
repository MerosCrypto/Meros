include MainImports

#Global variables used throught Main.
var
    events: EventEmitter = newEventEmitter() #EventEmitter for queries and new data.

    #Lattice.
    lattice: Lattice = newLattice()
    genesisSend: Index

    #Network.
    network: Network

    #UI.
    ui: UI

#Handle node level events.
#Properly shutdown.
events.on(
    "quit",
    proc () {.raises: [Exception].} =
        #Shut down the UI.
        ui.shutdown()

        #Shut down the Network.
        network.shutdown()

        #Quit.
        quit(0)
)
