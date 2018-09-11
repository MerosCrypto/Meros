# TODO

Core:
- Filesystem.
- Network.
- Rest of the parse functions.
- Track Verifications.
- Track MeritRemovals and link them to the blockchain.
- Difficulty Vote node.
- Fork resolution for blocks of different types.
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

Improvements:
- Use custom errors.
- Replace awaits with yields.
- Make Miners/Validations/Merit State proper objects.
- Optimize SECP256K1Wrapper (memory copies, splices...).
- Rewrite GMP package (last update was 2015).
- Don't have BN round down; have it round to the closest number.

Behavior Changes:
- Don't use delimiters over data lengths (theoretically faster to read X than split).
- Retarget based on block count, not time.
- Have required work be based on account, not that TX, and infinitely precalculable.
- Finalize Argon2's Block parameters.

Bug fixes:
- Difficulty algorithm is rough and breaks on higher time intervals.
- Remove GMP's memory leak.

Documentation:
- Add comments to:
    - DB/Merit/State.nim
    
    - Wallet/Wallet.nim
- Use Documentation Comments.
- Ember Whitepaper.

Community Service:
- Create a Nimble library out of Base.
- Create a Nimble library out of Argon2.
