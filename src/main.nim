#The Main files include each other sequentially.
#It starts with MainImports.
#MainImports is included by MainConstants.
#MainConstants is included by MainGlobals.
#MainGlobals is included by MainDatabase.
#MainDatabase is included by MainVerifications.
#MainVerifications is included by MainMerit.
#MainMerit is included by MainLattice.
#MainLattice is included by MainPersonal.
#MainPersonal is included by MainNetwork.
#MainNetwork is included by MainUI.
#It ends with include MainUI.

#We could include all of them in this file, but then all the other files would throw errors.
#IDEs can't, and shouldn't, detect that an external file includes that file, and the external file resolves the dependencies.

#Include the last file in the sequence.
include MainUI

#Spawn the core stuff on a thread since the UI must be on the main thread.
proc main() {.thread.} =
    mainDatabase()
    mainVerifications()
    mainMerit()
    mainLattice()
    mainPersonal()
    mainNetwork()
    mainRPC()

    runForever()

#If there's no GUI...
when defined(nogui):
    #Run main.
    main()
#If there is one...
else:
    #Spawn main on a thread.
    spawn main()
    #Run the GUI on the main thread,
    mainGUI()
    #Sync the threads.
    sync()
