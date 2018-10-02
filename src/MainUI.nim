include MainNetwork

#------------ UI ------------
#UI object.
var ui: UI = newUI(events, 1000, 500)

#Handle quit statements.
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
