discard """
The Network files include each other sequentially.
It starts with NetworkImports.
NetworkImports is included by NetworkCore.
NetworkCore is included by NetworkSync.
It ends with include NetworkSync.

The original plan was to have Imports + Core be Network.nim, and then we'd solely include Sync.
This was because Sync was adding 150 lines to a lib that's already 300 lines.
That said, Sync was throwing IDE errors since it didn't have any of the imports/core functions.
The solution was to create this include chain, even if it's a bit overblown.
"""

#Include the last file in the sequence.
include NetworkSync
