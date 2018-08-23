# TODO

Core:
- Chain Params file.
- Use custom errors.
- Write tests.
- Write a Lattice/Database State.
- Parse functions (which requires knowing the state).
- Difficulty Vote node.
- Account, Lattice, and Database files.
- Filesystem code.
- Network.
- UI.

Features:
- Have Merit disappear after 365.25\*24\*6 (52596) blocks.
- Have Merit Holders indexable by the order they got Merit in.
- Have Difficulty retarget:
    - Every block until the end of month 1.
    - Every hour until the end of month 3.
    - Every 6 hours until the end of month 6.
    - Every 12 hours until the end of the year.
    - Every day from then on.
- Threaded/dedicated miner.

Improvements:
- Optimize SECP256K1Wrapper (memory copies, splices...).
- Rewrite GMP package (last update was 2015).
- Don't round down; round to the closer number.

Bug fixes and behavior changes:
- Difficulty does a minimal amount of scaling with longer time periods.
- Remove GMP's memory leak.
- Put object definitions into dedicated files.
- Finalize Argon2 parameters.

Documentation:
- Add comments to:
    - lib/Base.nim

    - DB/Merit/Merkle.nim
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
