#Include and link Sodium.
{.passC: "-Isrc/lib/libsodium".}
{.passL: "-lsodium".}

#---------- Ed25519 ----------

#Define the Ed25519 objects.
type
    Ed25519State* {.
        header: "../../src/lib/libsodium/sodium.h",
        importc: "crypto_sign_ed25519ph_state"
    .} = object
    Seed* = array[32, cuchar]
    PrivateKey* = array[64, cuchar]
    PublicKey* = array[32, cuchar]

#Sodium function for creating a key pair.
func sodiumKeyPair*(
    pub: ptr cuchar,
    priv: ptr cuchar,
    seed: ptr cuchar
): int {.
    header: "../../src/lib/libsodium/sodium.h",
    importc: "crypto_sign_ed25519_seed_keypair"
.}

#Sodium function for initiating a state.
func sodiumInitState*(state: ptr Ed25519State): int {.
    header: "../../src/lib/libsodium/sodium.h",
    importc: "crypto_sign_ed25519ph_init"
.}

#Sodium function for updating a state.
func sodiumUpdateState*(
    state: ptr Ed25519State,
    msg: ptr char,
    len: culong
): int {.
    header: "../../src/lib/libsodium/sodium.h",
    importc: "crypto_sign_ed25519ph_update"
.}

#Sodium function for signing a message.
func sodiumSign*(
    state: ptr Ed25519State,
    sig: ptr char,
    len: ptr culong,
    priv: PrivateKey
): int {.
    header: "../../src/lib/libsodium/sodium.h",
    importc: "crypto_sign_ed25519ph_final_create"
.}

#Sodium function for verifying a message.
func sodiumVerify*(
    state: ptr Ed25519State,
    sig: ptr char,
    pub: PublicKey
): int {.
    header: "../../src/lib/libsodium/sodium.h",
    importc: "crypto_sign_ed25519ph_final_verify"
.}
