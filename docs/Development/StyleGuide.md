# Meros Style Guide

1. Be concise, but never implicit.
2. Use a 4-space ident.
3. Try to remain under 80 characters per line.
4. For `var`/`let`, use pascalCase for naming.
5. For `type`/`type` values, use CamelCase.
6. For `const`, use ALL_CAPS, with underscores between words.
7. Use a single `var`/`let`/`type` block when defining things next to each other.
8. Always define the type of your `var`s, `let`s, and `proc` arguments INDIVIDUALLY (don’t group multiple arguments with a single type).
9. Always prefix an `enum` value with it’s `enum` (`Enum.EnumValue`).
10. Pure code is generally preferable over impure code.
11. Use `func` wherever possible.
12. All functions, which aren’t async, must be decorated with the `{.raises.}` pragma.
13. Comment your code as needed. It is better to comment too much than too little.
