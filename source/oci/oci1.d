module oci1;

/* Copyright (c) 1997, 2005, Oracle. All rights reserved.  */

import oratypes;
import ociap;

/* NOTE:  See 'header_template.doc' in the 'doc' dve under the 'forms'
      directory for the header file template that includes instructions.
*/

/*
   NAME
     oci1.h - Cartridge Service definitions

   DESCRIPTION
     <short description of component this file declares/defines>

   RELATED DOCUMENTS

   INSPECTION STATUS
     Inspection date:
     Inspection status:
     Estimated increasing cost defects per page:
     Rule sets:

   ACCEPTANCE REVIEW STATUS
     Review date:
     Review status:
     Reviewers:

   PUBLIC FUNCTION(S)
     <list of external functions declared/defined - with one-line descriptions>

   PRIVATE FUNCTION(S)
     <list of static functions defined in .c file - with one-line descriptions>

   EXAMPLES

   NOTES
     <other useful comments, qualifications, etc.>

   MODIFIED   (MM/DD/YY)
   mbastawa    09/16/05 - dbhygiene
   dmukhin     06/29/05 - ANSI prototypes; miscellaneous cleanup
   nramakri    01/16/98 - remove #ifdef NEVER clause
   ewaugh      12/18/97 - Turn type wrappers into functions.
   skabraha    12/02/97 - Adding data structures & constants for OCIFile
   rhwu        12/02/97 - OCI Thread
   nramakri    12/15/97 - move to core4
   ewaugh      12/11/97 - add OCIFormat package constants
   ssamu       12/10/97 - do not include s.h
   nramakri    11/19/97 - add OCIExtract definitions
   ssamu       11/14/97 - creation

*/

extern (C):

/*---------------------------------------------------------------------------
                     PUBLIC TYPES AND CONSTANTS
  ---------------------------------------------------------------------------*/

/* Constants required by the OCIFormat package. */

// Adam Walker 18-Jul-2021
//enum OCIFormatEnd = OCIFormatTEnd();
alias OCIFormatEnd = OCIFormatTEnd;

enum OCIFormatDP = 6;

/*----------------- Public Constants for OCIFile -------------------------*/

/* flags for open.*/
/* flags for mode */
enum OCI_FILE_READ_ONLY = 1; /* open for read only */
enum OCI_FILE_WRITE_ONLY = 2; /* open for write only */
enum OCI_FILE_READ_WRITE = 3; /* open for read & write */
/* flags for create */
enum OCI_FILE_EXIST = 0; /* the file should exist */
enum OCI_FILE_CREATE = 1; /* create if the file doesn't exist */
enum OCI_FILE_EXCL = 2; /* the file should not exist */
enum OCI_FILE_TRUNCATE = 4; /* create if the file doesn't exist,
   else truncate file the file to 0 */
enum OCI_FILE_APPEND = 8; /* open the file in append mode */

/* flags for seek */
enum OCI_FILE_SEEK_BEGINNING = 1; /* seek from the beginning of the file */
enum OCI_FILE_SEEK_CURRENT = 2; /* seek from the current position */
enum OCI_FILE_SEEK_END = 3; /* seek from the end of the file */

enum OCI_FILE_FORWARD = 1; /* seek forward              */
enum OCI_FILE_BACKWARD = 2; /* seek backward             */

/* file type */
enum OCI_FILE_BIN = 0; /* binary file */
enum OCI_FILE_TEXT = 1; /* text file */
enum OCI_FILE_STDIN = 2; /* standard i/p */
enum OCI_FILE_STDOUT = 3; /* standard o/p */
enum OCI_FILE_STDERR = 4; /* standard error */

/* Represents an open file */
struct OCIFileObject;

/*--------------------- OCI Thread Object Definitions------------------------*/

/* OCIThread Context */
struct OCIThreadContext;

/* OCIThread Mutual Exclusion Lock */
struct OCIThreadMutex;

/* OCIThread Key for Thread-Specific Data */
struct OCIThreadKey;

/* OCIThread Thread ID */
struct OCIThreadId;

/* OCIThread Thread Handle */
struct OCIThreadHandle;

/*-------------------- OCI Thread Callback Function Pointers ----------------*/

/* OCIThread Key Destructor Function Type */
alias OCIThreadKeyDestFunc = void function (void*);

/* Flags passed into OCIExtractFromXXX routines to direct processing         */
enum OCI_EXTRACT_CASE_SENSITIVE = 0x1; /* matching is case sensitive     */
enum OCI_EXTRACT_UNIQUE_ABBREVS = 0x2; /* unique abbreviations for keys
   are allowed                    */
enum OCI_EXTRACT_APPEND_VALUES = 0x4; /* if multiple values for a key
   exist, this determines if the
   new value should be appended
   to (or replace) the current
   list of values                 */

/* Constants passed into OCIExtractSetKey routine */
enum OCI_EXTRACT_MULTIPLE = 0x8; /* key can accept multiple values */
enum OCI_EXTRACT_TYPE_BOOLEAN = 1; /* key type is boolean            */
enum OCI_EXTRACT_TYPE_STRING = 2; /* key type is string             */
enum OCI_EXTRACT_TYPE_INTEGER = 3; /* key type is integer            */
enum OCI_EXTRACT_TYPE_OCINUM = 4; /* key type is ocinum             */

/*---------------------------------------------------------------------------
                     PRIVATE TYPES AND CONSTANTS
  ---------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------
                           PUBLIC FUNCTIONS
  ---------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------
                          PRIVATE FUNCTIONS
  ---------------------------------------------------------------------------*/

/* OCI1_ORACLE */
