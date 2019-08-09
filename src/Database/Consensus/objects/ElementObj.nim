#Finals lib.
import finals

#BLS Nimble package.
#It's atrocious to directly import this.
#We should import MinerWallet, or at least BLS.
#That said, both use Errors which imports this via MeritRemovalObj.
import mc_bls

#Element object.
finalsd:
    type
        Element* = ref object of RootObj
            #Public key of owner
            holder* {.final.}: PublicKey
            #Nonce
            nonce* {.final.}: int
