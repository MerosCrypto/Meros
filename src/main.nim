#The Main files include each other sequentially.
#It starts with MainImports.
#MainImports is included by MainGlobals.
#MainGlobals is included by MainLattice.
#MainLattice is included by MainNetwork.
#MainNetwork is included by MainUI.
#It ends with include MainUI.

#We could include all of them in this file, but then all the other files would throw errors.
#IDEs can't, and shouldn't, detect that an external file includes that file, and the external file resolves the dependencies.

#Include the last file in the sequence.
include MainUI

#Run forever.
runForever()
