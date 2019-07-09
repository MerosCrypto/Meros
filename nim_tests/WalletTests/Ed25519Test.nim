#Ed25519 Test.

import ../../src/Wallet/Ed25519

proc test*() =
    var keys: seq[EdPublicKey] = @[
        newEdPublicKey("55ed80d3a5666d25e66620db7cf21d68028e6b642fe2938d88985430d02523c5"),
        newEdPublicKey("64cdbddae4c3ac13d3fba3d84a933a90ea4cb63c958d20800ca588c9357a0a9e")
    ]
    assert(keys.aggregate().verify("test", newEdSignature("f5483c9bec45a2601ea1ba3765fff6cf321daf1ed9cc8fed3b31eb2db475a6b92dd272e2e124cb47945410272949467181d574fc35333eb3853e570f3658c806")))

    echo "Finished the Wallet/Ed25519 Test."
