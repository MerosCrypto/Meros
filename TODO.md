# TODO

Core:
- Async Sockets.
- Rest of the parse functions.
- Track Verifications.
- Track MeritRemovals and link them to the blockchain.
- Difficulty Vote node.
- Fork resolution for blocks of different types.
- Filesystem.
- UI.
- Write tests.

Features:
- Chain Params file.
- Have Merit disappear after 50000 (365.25\*24\*6 is 52596; just rounded down for ease) blocks.
- Have Merit Holders indexable by the order they got Merit in.
- Have Difficulty retarget:
    - Every block until the end of month 1.
    - Every hour until the end of month 3.
    - Every 6 hours until the end of month 6.
    - Every 12 hours until the end of the year.
    - Every day from then on.
- Threaded/dedicated miner.

Improvements:
- Use custom errors.
- Make Miners/Validations proper objects.
- Optimize SECP256K1Wrapper (memory copies, splices...).
- Rewrite GMP package (last update was 2015).
- Don't round down; round to the closer number.

Bug fixes and behavior changes:
- Difficulty does a minimal amount of scaling with longer time periods.
- Retarget based on block count, not time.
- Have required work be based on account, not that TX, and infinitely precalculable.
- Remove GMP's memory leak.
- Put object definitions into dedicated files.
- Finalize Argon2 parameters.

Documentation:
- Add comments to:
    - DB/Merit/State.nim

    - DB/Lattice/Lattice.nim

    - DB/Database.nim
    - DB/State.nim

    - Wallet/PublicKey.nim
    - Wallet/Wallet.nim
- Use Documentation Comments.
- Ember Whitepaper.

Community Service:
- Create a Nimble library out of Base.
- Create a Nimble library out of Argon2.
