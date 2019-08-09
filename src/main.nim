discard """
The Main files are an "include chain". They include each other sequentially, in the following orders:
    MainImports
    MainChainParams
    MainGlobals
    MainDatabase
    MainConsensus
    MainMerit
    MainTransactions
    MainPersonal
    MainNetwork
    MainInterfaces

We could include all of them in this file, but then all the other files would throw errors.
IDEs can't, and shouldn't, detect that an external file includes that file, and the external file resolves the dependency requirements.
"""

#Include the last file in the chain.
include MainInterfaces

#Enable running main on a thread since the GUI must always run on the main thread.
proc main() {.thread.} =
    {.gcsafe.}:
        mainDatabase()
        mainConsensus()
        mainMerit()
        mainTransactions()
        mainPersonal()
        mainNetwork()
        mainRPC()

        runForever()

#If we weren't compiled with a GUI...
when defined(nogui):
    #Run main.
    main()
#If we were...
else:
    #If it's disabled...
    if not config.gui:
        main()
    #If it's enabled...
    else:
        #Spawn main on a thread.
        spawn main()
        #Run the GUI on the main thread,
        mainGUI()
        #If WebView exits, perform a safe shutdown.
        toRPC.send(%* {
            "module": "system",
            "method": "quit",
            "args": []
        })
