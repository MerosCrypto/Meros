include MainNetwork

#Open the channels.
fromMain.open()
toRPC.open()
toGUI.open()

proc mainRPC() {.forceCheck: [].} =
    {.gcsafe.}:
        #Create the RPC.
        rpc = newRPC(functions, addr toRPC, addr toGUI)

        try:
            #Start the RPC.
            asyncCheck rpc.start()
            #Start listening.
            asyncCheck rpc.listen(config)
        except Exception as e:
            doAssert(false, "Couldn't start the RPC: " & e.msg)

when not defined(nogui):
    proc mainGUI() {.forceCheck: [].} =
        #Create the GUI.
        newGUI(addr fromMain, addr toRPC, addr toGUI, 800, 500)
