#Delimiter.
var delim*: string = $(char(0))

#Joins two string with the delimiter between the two string.
proc `!`*(first: string, second: string): string =
    first & delim & second
