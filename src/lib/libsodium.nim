#Include and link Sodium.
{.passC: "-Isrc/lib/libsodium".}
{.passL: "-lsodium".}

#---------- ED25519 ----------

#Define the ED25519 objects.
type
    ED25519State* {.
        header: "../../src/lib/libsodium/sodium.h",
        importc: "crypto_sign_ed25519ph_state"
    .} = object
    PrivateKey* = array[64, cuchar]
    PublicKey* = array[32, cuchar]

#Sodium function for creating a key pair.
proc sodiumKeyPair*(
    pub: ptr cuchar,
    priv: ptr cuchar
): int {.
    header: "../../src/lib/libsodium/sodium.h",
    importc: "crypto_sign_ed25519_keypair"
.}

#Sodium function for creating a Public Key.
proc sodiumPublicKey*(
    pub: ptr cuchar,
    priv: ptr cuchar
): int {.
    header: "../../src/lib/libsodium/sodium.h",
    importc: "crypto_sign_ed25519_sk_to_pk"
.}

#Sodium function for initiating a state.
proc sodiumInitState*(state: ptr ED25519State): int {.
    header: "../../src/lib/libsodium/sodium.h",
    importc: "crypto_sign_ed25519ph_init"
.}

#Sodium function for updating a state.
proc sodiumUpdateState*(
    state: ptr ED25519State,
    msg: ptr char,
    len: culong
): int {.
    header: "../../src/lib/libsodium/sodium.h",
    importc: "crypto_sign_ed25519ph_update"
.}

#Sodium function for signing a message.
proc sodiumSign*(
    state: ptr ED25519State,
    sig: ptr char,
    len: ptr culong,
    priv: PrivateKey
): int {.
    header: "../../src/lib/libsodium/sodium.h",
    importc: "crypto_sign_ed25519ph_final_create"
.}

#Sodium function for verifying a message.
proc sodiumVerify*(
    state: ptr ED25519State,
    sig: ptr char,
    pub: PublicKey
): int {.
    header: "../../src/lib/libsodium/sodium.h",
    importc: "crypto_sign_ed25519ph_final_verify"
.}
