type PrivKey* = ref object of RootObj
    secret: array[32, uint8]
