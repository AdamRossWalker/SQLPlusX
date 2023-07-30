module ocidem;

/*
 *
 */

import oratypes;
import ocidfn;

extern (C):

/* Copyright (c) 1991, 2005, Oracle. All rights reserved.  */
/* Copyright (c) 1991, 2005, Oracle. All rights reserved.  */
/*
   NAME
     ocidem.h - OCI demo header
   MODIFIED   (MM/DD/YY)
    dmukhin    06/29/05  - ANSI prototypes; miscellaneous cleanup
    whe        04/07/99 -  bug#810071
    whe        03/19/99 -  lrg 32079 etc.: putting static back for oci_func_tab
    nmacnaug   02/02/99 -  static declarations should not be in header files
    mygopala   09/22/97 -  Fix for bug 550351
    surman     03/14/97 -  Merge 413362 to 8.0.3
    surman     11/08/96 -  413362: Add SS_64BIT_SERVER macro
    emendez    04/07/94 -  merge changes from branch 1.6.710.1
    emendez    02/02/94 -  Fix for bug 157576
    jnlee      01/05/93 -  include oratypes.h once, make oci_func_tab static
    rkooi2     10/26/92 -  More portability mods
    rkooi2     10/22/92 -  Change text back to char to avoid casts
    rkooi2     10/20/92 -  Changes to make it portable
    sjain      03/16/92 -  Creation
*/

/*
 *  ocidem.h
 *
 *  Declares additional functions and data structures
 *  used in the OCI C sample programs.
 */

/* ORATYPES */

/* OCIDFN */

/*  internal/external datatype codes */
enum VARCHAR2_TYPE = 1;
enum NUMBER_TYPE = 2;
enum INT_TYPE = 3;
enum FLOAT_TYPE = 4;
enum STRING_TYPE = 5;
enum ROWID_TYPE = 11;
enum DATE_TYPE = 12;

/*  ORACLE error codes used in demonstration programs */
enum VAR_NOT_IN_LIST = 1007;

enum NO_DATA_FOUND = 1403;

enum NULL_VALUE_RETURNED = 1405;

/*  some SQL and OCI function codes */
enum FT_INSERT = 3;
enum FT_SELECT = 4;
enum FT_UPDATE = 5;
enum FT_DELETE = 9;

enum FC_OOPEN = 14;

/*
 *  OCI function code labels,
 *  corresponding to the fc numbers
 *  in the cursor data area.
 */

/* 1-2 */
/* 3-4 */
/* 5-6 */
/* 7-8 */
/* 9-10 */
/* 11-12 */
/* 13-14 */
/* 15-16 */
/* 17-18 */
/* 19-20 */
/* 21-22 */
/* 23-24 */
/* 25-26 */
/* 27-28 */
/* 29-30 */
/* 31-32 */
/* 33-34 */
/* 35-36 */
/* 37-38 */
/* 39-40 */
/* 41-42 */
/* 43-44 */
/* 45-46 */
/* 47-48 */
/* 49-50 */
/* 51-52 */
/* 53-54 */
/* 55-56 */
/* 57-58 */
/* 59-60 */
/* 61-62 */
/* 63-64 */
/* 65-66 */
extern __gshared const(text)*[67] oci_func_tab;

/* OCIDEM */
