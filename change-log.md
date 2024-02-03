
# Change Log

## V1.2.0

03-Feb-2024

A couple of minor tweaks so that the autocomplete and command history will respond to the up/down arrow keys if the current command is single line.  Added a tool tip to the autocomplete popup to indicate CTRL+Up/Down can be used.

## V1.1.0

08-Aug-2023

A large release to support UTF-8.  This version replaces the glyph lookup system, manual keyboard mapping (so should be good for all keyboards now), and most string processing to support surrogate groups.  However, it does not support graphemes.

There is a new command SCRIPTFILEFORMAT and loaded files are now translated into UTF-8.  So if you have ASCII scripts which include characters over the 7 bit threshold, consider using this.  A warning message is displayed if invalid code points are encountered during transcoding.

This change was much larger than I initially intended, so there is a risk of regressions.

## V1.0.1

31-Jul-2023

A minor change to support US keyboard layout, however international support is limited.

## V1.0.0

30-Jul-2023

Initial public release.  This has been in development and private use for a few years, and so is fairly stable.
