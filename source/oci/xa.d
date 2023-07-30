module xa;

/* Copyright (c) 1992, 2006, Oracle. All rights reserved.  */

import core.stdc.config : c_long;

/*
   NAME
     xa.h - <one-line expansion of the name>
   DESCRIPTION
     <short description of component this file declares/defines>
   PUBLIC FUNCTION(S)
     <list of external functions declared/defined - with one-line descriptions>
   PRIVATE FUNCTION(S)
     <list of static functions defined in .c file - with one-line descriptions>
   RETURNS
     <function return values, for .c file with single function>
   NOTES
     <other useful comments, qualifications, etc.>

     This is the public XA .h file

   MODIFIED   (MM/DD/YY)
    yohu       08/27/06  - XA/RAC project changes: XAER_AFFINITY
    dmukhin    06/29/05  - ANSI prototypes; miscellaneous cleanup
    whe        09/01/99 -  976457:check __cplusplus for C++ code
    ntang      10/20/98 -  Remove TMCACHE & TMFORCL
    abhide     08/04/97 -  implement xaoforcl
    abhide     07/23/97 -  XA OTS project changes
    schandra   02/20/96 -  lint
    abhide     04/07/94 -  merge changes from branch 1.1.710.1
    abhide     02/14/94 -  Creation
    abhide     02/10/94 -  Creation
    abhide     02/10/94 -  Creation
*/
/*
 * xa.h header
 *      Typed in from X/Open doc of March 13, 1990
 *      Updated to Parsippany II draft, March, 1991
 *      Updated to Co Review draft, 19 Sep 1991
 */

extern (C):

/*
 * Transaction branch idenimport core.stdc.config;

tification: XID and NULLXID:
 */

enum XIDDATASIZE = 128; /* size in bytes */
enum MAXGTRIDSIZE = 64; /* maximum size in bytes of gtrid */
enum MAXBQUALSIZE = 64; /* maximum size in bytes of bqual */


struct xid_t
{
    c_long formatID; /* format identifier */
    c_long gtrid_length; /* value from 1 through 64 */
    c_long bqual_length; /* value from 1 through 64 */
    char[XIDDATASIZE] data;
}

alias XID = xid_t;

/*
 * A value of -1 in formatID means that the XID is null.
 */
/*
 * Declarations of routines by which RMs call TMs:
 */

int ax_reg (int, XID*, c_long);
int ax_unreg (int, c_long);
/*
 * XA Switch Data Structure
 */
enum RMNAMESZ = 32; /* length of resource manager name, */
/* including the null terminator */
enum MAXINFOSIZE = 256; /* maximum size in bytes of xa_info strings, */
/* including the null terminator */
struct xa_switch_t
{
    char[RMNAMESZ] name; /* name of resource manager */
    c_long flags; /* resource manager specific options */
    c_long version_; /* must be 0 */

    int function (char*, int, c_long) xa_open_entry; /*xa_open function pointer*/
    int function (char*, int, c_long) xa_close_entry; /*xa_close function pointer*/
    int function (XID*, int, c_long) xa_start_entry; /*xa_start function pointer*/
    int function (XID*, int, c_long) xa_end_entry; /*xa_end function pointer*/
    int function (XID*, int, c_long) xa_rollback_entry;
    /*xa_rollback function pointer*/
    int function (XID*, int, c_long) xa_prepare_entry; /*xa_prepare function pointer*/
    int function (XID*, int, c_long) xa_commit_entry; /*xa_commit function pointer*/
    int function (XID*, c_long, int, c_long) xa_recover_entry;
    /*xa_recover function pointer*/
    int function (XID*, int, c_long) xa_forget_entry; /*xa_forget function pointer*/
    int function (int*, int*, int, c_long) xa_complete_entry;
}

/*
 * Flag definition for the RM switch
 */
enum TMNOFLAGS = 0x00000000L; /* no resource manager features
   selected */
enum TMREGISTER = 0x00000001L; /* resource manager dynamically
   registers */
enum TMNOMIGRATE = 0x00000002L; /* resource manager does not support
   association migration */
enum TMUSEASYNC = 0x00000004L; /* resource manager supports
   asynchronous operations */
/*
 * Flag definitions for xa_ and ax_ routines
 */
/* Use TMNOFLAGS, defined above, when not specifying other flags */
enum TMASYNC = 0x80000000L; /* perform routine asynchronously */
enum TMONEPHASE = 0x40000000L; /* caller is using one-phase commit
optimisation */
enum TMFAIL = 0x20000000L; /* dissociates caller and marks
   transaction branch rollback-only */
enum TMNOWAIT = 0x10000000L; /* return if blocking condition
   exists */
enum TMRESUME = 0x08000000L; /* caller is resuming association
   with suspended transaction branch */
enum TMSUCCESS = 0x04000000L; /* dissociate caller from transaction
branch */
enum TMSUSPEND = 0x02000000L; /* caller is suspending, not ending,
   association */
enum TMSTARTRSCAN = 0x01000000L; /* start a recovery scan */
enum TMENDRSCAN = 0x00800000L; /* end a recovery scan */
enum TMMULTIPLE = 0x00400000L; /* wait for any asynchronous
   operation */
enum TMJOIN = 0x00200000L; /* caller is joining existing
transaction branch */
enum TMMIGRATE = 0x00100000L; /* caller intends to perform
migration */

/*
 * ax_() return codes (transaction manager reports to resource manager)
 */
enum TM_JOIN = 2; /* caller is joining existing transaction
branch */
enum TM_RESUME = 1; /* caller is resuming association with
   suspended transaction branch */
enum TM_OK = 0; /* normal execution */
enum TMER_TMERR = -1; /* an error occurred in the transaction
manager */
enum TMER_INVAL = -2; /* invalid arguments were given */
enum TMER_PROTO = -3; /* routine invoked in an improper context */

/*
 * xa_() return codes (resource manager reports to transaction manager)
 */
enum XA_RBBASE = 100; /* The inclusive lower bound of the
   rollback codes */
enum XA_RBROLLBACK = XA_RBBASE; /* The rollback was caused by an
   unspecified reason */
enum XA_RBCOMMFAIL = XA_RBBASE + 1; /* The rollback was caused by a
   communication failure */
enum XA_RBDEADLOCK = XA_RBBASE + 2; /* A deadlock was detected */
enum XA_RBINTEGRITY = XA_RBBASE + 3; /* A condition that violates the
   integrity of the resources was
   detected */
enum XA_RBOTHER = XA_RBBASE + 4; /* The resource manager rolled back the
   transaction for a reason not on this
   list */
enum XA_RBPROTO = XA_RBBASE + 5; /* A protocal error occurred in the
   resource manager */
enum XA_RBTIMEOUT = XA_RBBASE + 6; /* A transaction branch took too long*/
enum XA_RBTRANSIENT = XA_RBBASE + 7; /* May retry the transaction branch */
enum XA_RBEND = XA_RBTRANSIENT; /* The inclusive upper bound of the
   rollback codes */

enum XA_NOMIGRATE = 9; /* resumption must occur where
   suspension occurred */
enum XA_HEURHAZ = 8; /* the transaction branch may have been
   heuristically completed */
enum XA_HEURCOM = 7; /* the transaction branch has been
   heuristically comitted */
enum XA_HEURRB = 6; /* the transaction branch has been
   heuristically rolled back */
enum XA_HEURMIX = 5; /* the transaction branch has been
   heuristically committed and rolled
   back */
enum XA_RETRY = 4; /* routine returned with no effect
   and may be re-issued */
enum XA_RDONLY = 3; /* the transaction was read-only
   and has been committed */
enum XA_OK = 0; /* normal execution */
enum XAER_ASYNC = -2; /* asynchronous operation already
   outstanding */
enum XAER_RMERR = -3; /* a resource manager error occurred
in the transaction branch */
enum XAER_NOTA = -4; /* the XID is not valid */
enum XAER_INVAL = -5; /* invalid arguments were given */
enum XAER_PROTO = -6; /* routine invoked in an improper
   context */
enum XAER_RMFAIL = -7; /* resource manager unavailable */
enum XAER_DUPID = -8; /* the XID already exists */
enum XAER_OUTSIDE = -9; /* resource manager doing work */
/* outside global transaction */

enum XAER_AFFINITY = -10; /* XA on RAC: resumption must occur on
   RAC instance where the transaction
   branch was created */

/* ifndef XA_H */
