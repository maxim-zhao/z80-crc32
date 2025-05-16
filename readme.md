Z80 CRC32 benchmark
===================

This is a testbed for use with [Z80bench](https://github.com/maxim-zhao/z80bench) to optimise a Z80 [CRC32](https://wiki.osdev.org/CRC32) algorithm.

Current performance is approximately 100 cycles per byte.

This repository originated from [this forum thread](https://www.smspower.org/forums/18523-BitBangingAndCartridgeDumping) and the [ZEXALL-SMS source](https://github.com/maxim-zhao/zexall-sms).
It was later amended with code from [the Zilog Z80 CPU test suite](https://github.com/raxoft/z80test/).

Not all of the tests are strictly equal in terms of the API surface, for example some make use of aggressive unrolling and the fixed size of the area to be checksummed to gain a bit more speed. Nevertheless:

Results
-------

The benchmark checksums 32KB of data and validates the result is correct.
The final column assumes a CPU clock of 3579545Hz with no wait states.

|Algorithm      | Size |  Cycles | Cycles per byte | Time for 512KB |
|---------------|-----:|--------:|----------------:|---------------:|
|LUT            | 1096 | 4621688 |           141.0 |          20.7s |
|LUT UNROLL     | 2541 | 4201706 |           128.2 |          18.8s |
|CODEGEN        | 5405 | 5165628 |           157.6 |          23.1s |
|ASYNCHRONOUS   | 1125 | 4622280 |           141.0 |          20.7s |
|Z80TEST        | 1094 | 3704183 |           113.0 |          16.6s |
|Z80TEST UNROLL | 2413 | 3284201 |           100.2 |          14.7s |
