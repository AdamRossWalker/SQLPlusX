module oratypes;

/*
 Copyright (c) 1982, 2008, Oracle and/or its affiliates.All rights reserved.
*/

/*
 * $Header: oracore3/public/oratypes.h /nt/21 2009/01/01 19:48:06 sabchoud Exp $
 */

extern import core.stdc.limits;

extern (C):

// Added by Adam Walker 18-Jul-2021. For some reason these are missing from the
// D limits file.

// minimum signed 64 bit value
enum _I64_MIN = 0b1000000000000000000000000000000000000000000000000000000000000000;

// maximum signed 64 bit value
enum _I64_MAX = 0b0111111111111111111111111111111111111111111111111111111111111111;

// maximum unsigned 64 bit value
enum _UI64_MAX = 0xffffffffffffffff;

enum TRUE = 1;
enum FALSE = 0;

alias ub1 = ubyte;
alias sb1 = byte;

enum UB1MAXVAL = cast(ub1) UCHAR_MAX;
enum UB1MINVAL = cast(ub1) 0;
enum SB1MAXVAL = cast(sb1) SCHAR_MAX;
enum SB1MINVAL = cast(sb1) SCHAR_MIN;
enum MINUB1MAXVAL = cast(ub1) 255;
enum MAXUB1MINVAL = cast(ub1) 0;
enum MINSB1MAXVAL = cast(sb1) 127;
enum MAXSB1MINVAL = cast(sb1) -127;

alias ub2 = ushort;
alias sb2 = short;

enum UB2MAXVAL = cast(ub2) USHRT_MAX;
enum UB2MINVAL = cast(ub2) 0;
enum SB2MAXVAL = cast(sb2) SHRT_MAX;
enum SB2MINVAL = cast(sb2) SHRT_MIN;
enum MINUB2MAXVAL = cast(ub2) 65535;
enum MAXUB2MINVAL = cast(ub2) 0;
enum MINSB2MAXVAL = cast(sb2) 32767;
enum MAXSB2MINVAL = cast(sb2) -32767;

alias ub4 = uint;
alias sb4 = int;

enum UB4MAXVAL = cast(ub4) UINT_MAX;
enum UB4MINVAL = cast(ub4) 0;
enum SB4MAXVAL = cast(sb4) INT_MAX;
enum SB4MINVAL = cast(sb4) INT_MIN;
enum MINUB4MAXVAL = cast(ub4) 4294967295;
enum MAXUB4MINVAL = cast(ub4) 0;
enum MINSB4MAXVAL = cast(sb4) 2147483647;
enum MAXSB4MINVAL = cast(sb4) -2147483647;

/* --- Signed/Unsigned eight-byte scalar (orasb8/oraub8) --- */

alias oraub8 = ulong;
alias orasb8 = long;
/* __BORLANDC__ */

alias ub8 = ulong;
alias sb8 = long;

/* !lint */

enum ORAUB8MINVAL = cast(oraub8) 0;
enum ORAUB8MAXVAL = cast(oraub8) 18446744073709551615;
enum ORASB8MINVAL = cast(orasb8) -9223372036854775808;
enum ORASB8MAXVAL = cast(orasb8) 9223372036854775807;

enum MAXORAUB8MINVAL = cast(oraub8) 0;
enum MINORAUB8MAXVAL = cast(oraub8) 18446744073709551615;
enum MAXORASB8MINVAL = cast(orasb8) -9223372036854775807;
enum MINORASB8MAXVAL = cast(orasb8) 9223372036854775807;

enum UB1BITS = CHAR_BIT;
enum UB1MASK = (1 << (cast(uword) CHAR_BIT)) - 1;

alias oratext = ubyte;

alias eb1 = char;
alias eb2 = short;
alias eb4 = int;

enum EB1MAXVAL = cast(eb1) SCHAR_MAX;
enum EB1MINVAL = cast(eb1) 0;
enum MINEB1MAXVAL = cast(eb1) 127;
enum MAXEB1MINVAL = cast(eb1) 0;
enum EB2MAXVAL = cast(eb2) SHRT_MAX;
enum EB2MINVAL = cast(eb2) 0;
enum MINEB2MAXVAL = cast(eb2) 32767;
enum MAXEB2MINVAL = cast(eb2) 0;
enum EB4MAXVAL = cast(eb4) INT_MAX;
enum EB4MINVAL = cast(eb4) 0;
enum MINEB4MAXVAL = cast(eb4) 2147483647;
enum MAXEB4MINVAL = cast(eb4) 0;

alias b1 = byte;

enum B1MAXVAL = SB1MAXVAL;
enum B1MINVAL = SB1MINVAL;

alias b2 = short;

enum B2MAXVAL = SB2MAXVAL;
enum B2MINVAL = SB2MINVAL;

alias b4 = int;

enum B4MAXVAL = SB4MAXVAL;
enum B4MINVAL = SB4MINVAL;

alias text = ubyte;

alias OraText = ubyte;

alias eword = int;
alias uword = uint;
alias sword = int;

enum EWORDMAXVAL = cast(eword) INT_MAX;
enum EWORDMINVAL = cast(eword) 0;
enum UWORDMAXVAL = cast(uword) UINT_MAX;
enum UWORDMINVAL = cast(uword) 0;
enum SWORDMAXVAL = cast(sword) INT_MAX;
enum SWORDMINVAL = cast(sword) INT_MIN;
enum MINEWORDMAXVAL = cast(eword) 2147483647;
enum MAXEWORDMINVAL = cast(eword) 0;
enum MINUWORDMAXVAL = cast(uword) 4294967295;
enum MAXUWORDMINVAL = cast(uword) 0;
enum MINSWORDMAXVAL = cast(sword) 2147483647;
enum MAXSWORDMINVAL = cast(sword) -2147483647;

alias ubig_ora = ulong;
alias sbig_ora = long;
/* End of __BORLANDC__ */

/* End of lint */

enum UBIG_ORAMAXVAL = cast(ubig_ora) _UI64_MAX;
enum UBIG_ORAMINVAL = cast(ubig_ora) 0;
enum SBIG_ORAMAXVAL = cast(sbig_ora) _I64_MAX;
enum SBIG_ORAMINVAL = cast(sbig_ora) _I64_MIN;
enum MINUBIG_ORAMAXVAL = cast(ubig_ora) 4294967295;
enum MAXUBIG_ORAMINVAL = cast(ubig_ora) 0;
enum MINSBIG_ORAMAXVAL = cast(sbig_ora) 2147483647;
enum MAXSBIG_ORAMINVAL = cast(sbig_ora) -2147483647;

/* _WIN64 */

enum UBIGORABITS = UB1BITS * ubig_ora.sizeof;

alias dvoid = void;

alias lgenfp_t = void function ();

alias boolean = int;

enum SIZE_TMAXVAL = UB4MAXVAL;

enum MINSIZE_TMAXVAL = cast(size_t) 4294967295;

alias string = ubyte*;

alias utext = ushort;

