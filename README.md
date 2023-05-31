This is archived content of all publicly known/released CT60 TOS, CTPCI TOS and
to some extent also FireTOS releases in both source and binary form.

Up to version 1.04a, CT60 TOS and CTPCI TOS source code was fully available.
Later it was split into TOS060 2.0x and Drivers 1.0x packages where only the latter
had source code available. CTPCI TOS had gradually become FireTOS.

This branch contains merged archives of TOS060 2.00 & Drivers 1.00, TOS060 2.01
& Drivers 1.01 and then bits and pieces of various beta releases (those do not
include FireTOS as its development was somewhat separated) for easier tracking
of (public) changes. That means that source and binary files do not match in
all cases as shown in this table:

| Commit:                | [1.04a](https://github.com/mikrosk/ct60tos/commit/4ed32c25) | [TOS060 2.00 & Drivers 1.00](https://github.com/mikrosk/ct60tos/commit/7c75dc00) | [TOS060 2.01 & Drivers 1.01](https://github.com/mikrosk/ct60tos/commit/3a61ace2) | [TOS060 2.02 Beta 11 & Drivers 1.02 Beta 11](https://github.com/mikrosk/ct60tos/commit/1abbaff4)
| --- | --- | --- | --- | --- |
| TOS060 binary version  | 1.04a | 2.00  | 2.01  | 2.02 Beta 11
| TOS060 source version  | 1.04a | 1.04a | 1.04a | 2.02 Beta 11
| Drivers binary version | n/a   | 1.00  | 1.01  | 1.01
| Drivers source version | n/a   | 1.00  | 1.01  | 1.02 Beta 11

All beta versions were spread as `ctpcitos.bin` file, i.e. it had the file
`drivers.hex` included within. The official Drivers 1.01 release was the last
to contain a separate `drivers.hex`.

Apart from the Beta 11 from which the source code was recovered there have been additional archives discovered, namely:

- Beta 8 from 8.4.2012
- Beta 10 from 6.5.2012 (supposedly the most stable one)
- Beta 11 from 23.6.2012
- Beta 11 from 3.7.2012 (this one seems to be the build related to the source release)
- Beta 11 from 11.11.2012 (tosstplx.zip)
- Beta 12 from 28.11.2012

All of them can be found in the `master` branch as separate commits.

The official documentation by Didier Méquignon available online (released packages can be found in the [releases](https://github.com/mikrosk/ct60tos/releases)):

- [CT60TOS 1.03c](http://www.tho-otto.de/hypview/hypview.cgi?url=https://github.com/mikrosk/ct60tos/raw/1eb9075d63fb3ed776070a097542a191ccff058d/doc/english/ct60.hyp) ([source tree](https://github.com/mikrosk/ct60tos/tree/1eb9075d63fb3ed776070a097542a191ccff058d))
- [CT60TOS 2.01](http://www.tho-otto.de/hypview/hypview.cgi?url=https://github.com/mikrosk/ct60tos/raw/2.01/doc/ct60/english/ct60.hyp) ([source tree](https://github.com/mikrosk/ct60tos/tree/2.01))
- [FireTOS 2.01](http://www.tho-otto.de/hypview/hypview.cgi?url=https://github.com/mikrosk/ct60tos/raw/2.01/doc/firebee/english/firebee.hyp) ([source tree](https://github.com/mikrosk/ct60tos/tree/2.01))
- [CTPCI Drivers 1.01](http://www.tho-otto.de/hypview/hypview.cgi?url=https://github.com/mikrosk/ct60tos/raw/db5de81f0b8bd130dfb04869d67204ec005861d3/doc/CTPCI.hyp) ([source tree](https://github.com/mikrosk/ct60tos/tree/db5de81f0b8bd130dfb04869d67204ec005861d3))

Website source files are available in the [gh-pages branch](https://github.com/mikrosk/ct60tos/tree/gh-pages).
