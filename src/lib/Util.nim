#Times standard lib.
import times

#Gets the epoch and returns it as an int.
proc getTime*(): uint {.raises: [].} =
    uint(times.getTime().toUnix())

#Left-pads data, with a char or string, until the data is a certain length.
func pad*(
    data: string,
    len: int,
    prefix: char | string = "0"
): string {.raises: [].} =
    result = data

    while result.len < len:
        result = prefix & result
