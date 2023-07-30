module odci;

/*
 *
 */

import oci;
import orl;
import oro;
import ort;

extern (C):

/* Copyright (c) 1998, 2010, Oracle and/or its affiliates.
All rights reserved. */

/*
   NAME
     odci.h - Oracle Data Cartridge Interface definitions

   DESCRIPTION
     This file contains Oracle Data Cartridge Interface definitions. These
     include the ODCI Types and Constants.

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
     None.

   PRIVATE FUNCTION(S)
     None.

   EXAMPLES

   NOTES
     - The constants defined here are replica of the constants defined
       in ODCIConst Package defined as part of catodci.sql. If you change
       these do make the similar change in catodci.sql.

   MODIFIED   (MM/DD/YY)
   yhu         02/03/10 - add a new flag ODCI_INDEX_UGI
   spsundar    09/13/07 -
   yhu         06/02/06 - add callproperty for statistics
   yhu         05/22/06 - add ODCI_NODATA to speed rebuild empty index or ind.
                          part.
   srirkris    05/09/06 - change ODCIOrderByInfo_ind
   srirkris    02/06/06 - add definitions for CDI query.
   spsundar    02/17/06 - add fields/types for system managed domain idx
   yhu         02/08/06 - add RenameCol Na d RenameTopADT
   yhu         03/11/05 - add flags for rename column and rename table
   spsundar    11/28/05 - add fields/types for composite domain idx
   yhu         12/06/05 - mapping table for local text indexes
   dmukhin     06/29/05 - ANSI prototypes; miscellaneous cleanup
   ayoaz       04/21/03 - add CursorNum to ODCIEnv
   abrumm      12/30/02 - Bug #2223225: add define for
                          ODCI_ARG_DESC_LIST_MAXSIZE
   ayoaz       10/14/02 - Add Cardinality to ODCIArgDesc
   ayoaz       09/11/02 - add ODCIQueryInfo to ODCIIndexCtx
   yhu         09/19/02 - add ODCI_DEBUGGING_ON for ODCIEnv.EnvFlags
   hsbedi      10/10/02 - add object number into ODCIExtTableInfo
   ayoaz       08/30/02 - add ODCITable2 types
   tchorma     07/29/02 - Add ODCIFuncCallInfo type for WITH COLUMN CONTEXT
   hsbedi      06/29/02 - External table populate
   yhu         07/20/01 - add parallel degree in ODCIIndexInfo.
   abrumm      02/20/01 - ODCIExtTableInfo: add AccessParmBlob attribute
   abrumm      01/18/01 - ODCIExtTableInfo: add default directory
   spsundar    08/24/00 - Update attrbiute positions
   abrumm      08/04/00 - external tables changes: ODCIExtTableInfo, constants
   tchorma     09/11/00 - Add return code ODCI_FATAL
   tchorma     08/08/00 - Add Update Block References Option for Alter Index
   ayoaz       08/01/00 - Add ODCI_AGGREGATE_REUSE_CTX
   spsundar    06/19/00 - add ODCIEnv type
   abrumm      06/27/00 - add defines for ODCIExtTable flags
   abrumm      06/04/00 - external tables: ODCIExtTableInfo change; add ODCIEnv
   ddas        04/28/00 - extensible optimizer enhancements for 8.2
   yhu         06/05/00 - add a bit in IndexInfoFlags for trans. tblspc
   yhu         04/10/00 - add ODCIPartInfo & remove ODCIIndexPartList
   abrumm      03/29/00 - external table support
   spsundar    02/14/00 - update odci definitions for 8.2
   nagarwal    03/07/99 - bug# 838308 - set estimate_stats=1
   rmurthy     11/09/98 - add blocking flag
   ddas        10/31/98 - add ODCI_QUERY_SORT_ASC and ODCI_QUERY_SORT_DESC
   ddas        05/26/98 - fix ODCIPredInfo flag bits
   rmurthy     06/03/98 - add macro for RegularCall
   spsundar    05/08/98 - add constants related to ODCIIndexAlter options
   rmurthy     04/30/98 - remove include s.h
   rmurthy     04/20/98 - name fixes
   rmurthy     04/13/98 - add C mappings for odci types
   alsrivas    04/10/98 - adding defines for ODCI_INDEX1
   jsriniva    04/04/98 - Creation

*/

/*---------------------------------------------------------------------------*/
/*                         SHORT NAMES SUPPORT SECTION                       */
/*---------------------------------------------------------------------------*/

/* The following are short names that are only supported on IBM mainframes
 *   with the SLSHORTNAME defined.
 * With this all subsequent long names will actually be substituted with
 *  the short names here
 */

/* SLSHORTNAME */

/*---------------------------------------------------------------------------
                     PUBLIC TYPES AND CONSTANTS
  ---------------------------------------------------------------------------*/

/* Constants for Return Status */
enum ODCI_SUCCESS = 0;
enum ODCI_ERROR = 1;
enum ODCI_WARNING = 2;
enum ODCI_ERROR_CONTINUE = 3;
enum ODCI_FATAL = 4;

/* Constants for ODCIPredInfo.Flags */
enum ODCI_PRED_EXACT_MATCH = 0x0001;
enum ODCI_PRED_PREFIX_MATCH = 0x0002;
enum ODCI_PRED_INCLUDE_START = 0x0004;
enum ODCI_PRED_INCLUDE_STOP = 0x0008;
enum ODCI_PRED_OBJECT_FUNC = 0x0010;
enum ODCI_PRED_OBJECT_PKG = 0x0020;
enum ODCI_PRED_OBJECT_TYPE = 0x0040;
enum ODCI_PRED_MULTI_TABLE = 0x0080;
enum ODCI_PRED_NOT_EQUAL = 0x0100;

/* Constants for QueryInfo.Flags */
enum ODCI_QUERY_FIRST_ROWS = 0x01;
enum ODCI_QUERY_ALL_ROWS = 0x02;
enum ODCI_QUERY_SORT_ASC = 0x04;
enum ODCI_QUERY_SORT_DESC = 0x08;
enum ODCI_QUERY_BLOCKING = 0x10;

/* Constants for ScnFlg(Func /w Index Context) */
enum ODCI_CLEANUP_CALL = 1;
enum ODCI_REGULAR_CALL = 2;

/* Constants for ODCIFuncInfo.Flags */
enum ODCI_OBJECT_FUNC = 0x01;
enum ODCI_OBJECT_PKG = 0x02;
enum ODCI_OBJECT_TYPE = 0x04;

/* Constants for ODCIArgDesc.ArgType */
enum ODCI_ARG_OTHER = 1;
enum ODCI_ARG_COL = 2; /* column */
enum ODCI_ARG_LIT = 3; /* literal */
enum ODCI_ARG_ATTR = 4; /* object attribute */
enum ODCI_ARG_NULL = 5;
enum ODCI_ARG_CURSOR = 6;

/* Maximum size of ODCIArgDescList array */
enum ODCI_ARG_DESC_LIST_MAXSIZE = 32767;

/* Constants for ODCIStatsOptions.Options */
enum ODCI_PERCENT_OPTION = 1;
enum ODCI_ROW_OPTION = 2;

/* Constants for ODCIStatsOptions.Flags */
enum ODCI_ESTIMATE_STATS = 0x01;
enum ODCI_COMPUTE_STATS = 0x02;
enum ODCI_VALIDATE = 0x04;

/* Constants for ODCIIndexAlter parameter alter_option */
enum ODCI_ALTIDX_NONE = 0;
enum ODCI_ALTIDX_RENAME = 1;
enum ODCI_ALTIDX_REBUILD = 2;
enum ODCI_ALTIDX_REBUILD_ONL = 3;
enum ODCI_ALTIDX_MODIFY_COL = 4;
enum ODCI_ALTIDX_UPDATE_BLOCK_REFS = 5;
enum ODCI_ALTIDX_RENAME_COL = 6;
enum ODCI_ALTIDX_RENAME_TAB = 7;
enum ODCI_ALTIDX_MIGRATE = 8;

/* Constants for ODCIIndexInfo.IndexInfoFlags */
enum ODCI_INDEX_LOCAL = 0x0001;
enum ODCI_INDEX_RANGE_PARTN = 0x0002;
enum ODCI_INDEX_HASH_PARTN = 0x0004;
enum ODCI_INDEX_ONLINE = 0x0008;
enum ODCI_INDEX_PARALLEL = 0x0010;
enum ODCI_INDEX_UNUSABLE = 0x0020;
enum ODCI_INDEX_ONIOT = 0x0040;
enum ODCI_INDEX_TRANS_TBLSPC = 0x0080;
enum ODCI_INDEX_FUNCTION_IDX = 0x0100;
enum ODCI_INDEX_LIST_PARTN = 0x0200;
enum ODCI_INDEX_UGI = 0x0400;

/* Constants for ODCIIndexInfo.IndexParaDegree */
enum ODCI_INDEX_DEFAULT_DEGREE = 32767;

/* Constants for ODCIEnv.EnvFlags */
enum ODCI_DEBUGGING_ON = 0x01;
enum ODCI_NODATA = 0x02;

/* Constants for ODCIEnv.CallProperty */
enum ODCI_CALL_NONE = 0;
enum ODCI_CALL_FIRST = 1;
enum ODCI_CALL_INTERMEDIATE = 2;
enum ODCI_CALL_FINAL = 3;
enum ODCI_CALL_REBUILD_INDEX = 4;
enum ODCI_CALL_REBUILD_PMO = 5;
enum ODCI_CALL_STATSGLOBAL = 6;
enum ODCI_CALL_STATSGLOBALANDPARTITION = 7;
enum ODCI_CALL_STATSPARTITION = 8;

/* Constants for ODCIExtTableInfo.OpCode */
enum ODCI_EXTTABLE_INFO_OPCODE_FETCH = 1;
enum ODCI_EXTTABLE_INFO_OPCODE_POPULATE = 2;

/* Constants (bit definitions) for ODCIExtTableInfo.Flag */
/* sampling type: row or block */
enum ODCI_EXTTABLE_INFO_FLAG_SAMPLE = 0x00000001;
enum ODCI_EXTTABLE_INFO_FLAG_SAMPLE_BLOCK = 0x00000002;
/* AccessParmClob, AccessParmBlob discriminator */
enum ODCI_EXTTABLE_INFO_FLAG_ACCESS_PARM_CLOB = 0x00000004;
enum ODCI_EXTTABLE_INFO_FLAG_ACCESS_PARM_BLOB = 0x00000008;

/* Constants for ODCIExtTableInfo.IntraSourceConcurrency */
enum ODCI_TRUE = 1;
enum ODCI_FALSE = 0;

/* Constants (bit definitions) for ODCIExtTable{Open,Fetch,Populate,Close}
 * Flag argument.
 */
enum ODCI_EXTTABLE_OPEN_FLAGS_QC = 0x00000001; /* caller is Query Coord */
enum ODCI_EXTTABLE_OPEN_FLAGS_SHADOW = 0x00000002; /* caller is shadow proc */
enum ODCI_EXTTABLE_OPEN_FLAGS_SLAVE = 0x00000004; /* caller is slave  proc */

enum ODCI_EXTTABLE_FETCH_FLAGS_EOS = 0x00000001; /* end-of-stream on fetch */

/* Constants for Flags argument to ODCIAggregateTerminate */
enum ODCI_AGGREGATE_REUSE_CTX = 1;

/* Constants for ODCIColInfo.Flags */
enum ODCI_COMP_FILTERBY_COL = 0x0001;
enum ODCI_COMP_ORDERBY_COL = 0x0002;
enum ODCI_COMP_ORDERDSC_COL = 0x0004;
enum ODCI_COMP_UPDATED_COL = 0x0008;
enum ODCI_COMP_RENAMED_COL = 0x0010;
enum ODCI_COMP_RENAMED_TOPADT = 0x0020;

/* Constants for ODCIOrderByInfo.ExprType */
enum ODCI_COLUMN_EXPR = 1;
enum ODCI_ANCOP_EXPR = 2;

/* Constants for ODCIOrderByInfo.SortOrder */
enum ODCI_SORT_ASC = 1;
enum ODCI_SORT_DESC = 2;
enum ODCI_NULLS_FIRST = 4;

/* Constants for ODCIPartInfo.PartOp */
enum ODCI_ADD_PARTITION = 1;
enum ODCI_DROP_PARTITION = 2;

/*---------------------------------------------------------------------------
                     ODCI TYPES
  ---------------------------------------------------------------------------*/
/*
 * These are C mappings for the OTS types defined in catodci.sql
 */

alias ODCIColInfo_ref = OCIRef_;
alias ODCIColInfoList = OCIColl_;
alias ODCIColInfoList2 = OCIColl_;
alias ODCIIndexInfo_ref = OCIRef_;
alias ODCIPredInfo_ref = OCIRef_;
alias ODCIRidList = OCIColl_;
alias ODCIIndexCtx_ref = OCIRef_;
alias ODCIObject_ref = OCIRef_;
alias ODCIObjectList = OCIColl_;
alias ODCIQueryInfo_ref = OCIRef_;
alias ODCIFuncInfo_ref = OCIRef_;
alias ODCICost_ref = OCIRef_;
alias ODCIArgDesc_ref = OCIRef_;
alias ODCIArgDescList = OCIColl_;
alias ODCIStatsOptions_ref = OCIRef_;
alias ODCIPartInfo_ref = OCIRef_;
alias ODCIEnv_ref = OCIRef_;
alias ODCIExtTableInfo_ref = OCIRef_; /* external table support */
alias ODCIGranuleList = OCIColl_; /* external table support */
alias ODCIExtTableQCInfo_ref = OCIRef_; /* external table support */
alias ODCIFuncCallInfo_ref = OCIRef_;
alias ODCINumberList = OCIColl_;
alias ODCIPartInfoList = OCIColl_;
alias ODCIColValList = OCIColl_;
alias ODCIColArrayList = OCIColl_;
alias ODCIFilterInfoList = OCIColl_;
alias ODCIOrderByInfoList = OCIColl_;
alias ODCIFilterInfo_ref = OCIRef_;
alias ODCIOrderByInfo_ref = OCIRef_;
alias ODCICompQueryInfo_ref = OCIRef_;

struct ODCIColInfo
{
    OCIString* TableSchema;
    OCIString* TableName;
    OCIString* ColName;
    OCIString* ColTypName;
    OCIString* ColTypSchema;
    OCIString* TablePartition;
    OCINumber ColFlags;
    OCINumber ColOrderPos;
    OCINumber TablePartitionIden;
    OCINumber TablePartitionTotal;
}

struct ODCIColInfo_ind
{
    OCIInd atomic;
    OCIInd TableSchema;
    OCIInd TableName;
    OCIInd ColName;
    OCIInd ColTypName;
    OCIInd ColTypSchema;
    OCIInd TablePartition;
    OCIInd ColFlags;
    OCIInd ColOrderPos;
    OCIInd TablePartitionIden;
    OCIInd TablePartitionTotal;
}

struct ODCIFuncCallInfo
{
    ODCIColInfo ColInfo;
}

struct ODCIFuncCallInfo_ind
{
    ODCIColInfo_ind ColInfo;
}

struct ODCIIndexInfo
{
    OCIString* IndexSchema;
    OCIString* IndexName;
    ODCIColInfoList* IndexCols;
    OCIString* IndexPartition;
    OCINumber IndexInfoFlags;
    OCINumber IndexParaDegree;
    OCINumber IndexPartitionIden;
    OCINumber IndexPartitionTotal;
}

struct ODCIIndexInfo_ind
{
    OCIInd atomic;
    OCIInd IndexSchema;
    OCIInd IndexName;
    OCIInd IndexCols;
    OCIInd IndexPartition;
    OCIInd IndexInfoFlags;
    OCIInd IndexParaDegree;
    OCIInd IndexPartitionIden;
    OCIInd IndexPartitionTotal;
}

struct ODCIPredInfo
{
    OCIString* ObjectSchema;
    OCIString* ObjectName;
    OCIString* MethodName;
    OCINumber Flags;
}

struct ODCIPredInfo_ind
{
    OCIInd atomic;
    OCIInd ObjectSchema;
    OCIInd ObjectName;
    OCIInd MethodName;
    OCIInd Flags;
}

struct ODCIFilterInfo
{
    ODCIColInfo ColInfo;
    OCINumber Flags;
    OCIAnyData* strt;
    OCIAnyData* stop;
}

struct ODCIFilterInfo_ind
{
    OCIInd atomic;
    ODCIColInfo_ind ColInfo;
    OCIInd Flags;
    OCIInd strt;
    OCIInd stop;
}

struct ODCIOrderByInfo
{
    OCINumber ExprType;
    OCIString* ObjectSchema;
    OCIString* TableName;
    OCIString* ExprName;
    OCINumber SortOrder;
}

struct ODCIOrderByInfo_ind
{
    OCIInd atomic;
    OCIInd ExprType;
    OCIInd ObjectSchema;
    OCIInd TableName;
    OCIInd ExprName;
    OCIInd SortOrder;
}

struct ODCICompQueryInfo
{
    ODCIFilterInfoList* PredInfo;
    ODCIOrderByInfoList* ObyInfo;
}

struct ODCICompQueryInfo_ind
{
    OCIInd atomic;
    OCIInd PredInfo;
    OCIInd ObyInfo;
}

struct ODCIObject
{
    OCIString* ObjectSchema;
    OCIString* ObjectName;
}

struct ODCIObject_ind
{
    OCIInd atomic;
    OCIInd ObjectSchema;
    OCIInd ObjectName;
}

struct ODCIQueryInfo
{
    OCINumber Flags;
    ODCIObjectList* AncOps;
    ODCICompQueryInfo CompInfo;
}

struct ODCIQueryInfo_ind
{
    OCIInd atomic;
    OCIInd Flags;
    OCIInd AncOps;
    ODCICompQueryInfo_ind CompInfo;
}

struct ODCIIndexCtx
{
    ODCIIndexInfo IndexInfo;
    OCIString* Rid;
    ODCIQueryInfo QueryInfo;
}

struct ODCIIndexCtx_ind
{
    OCIInd atomic;
    ODCIIndexInfo_ind IndexInfo;
    OCIInd Rid;
    ODCIQueryInfo_ind QueryInfo;
}

struct ODCIFuncInfo
{
    OCIString* ObjectSchema;
    OCIString* ObjectName;
    OCIString* MethodName;
    OCINumber Flags;
}

struct ODCIFuncInfo_ind
{
    OCIInd atomic;
    OCIInd ObjectSchema;
    OCIInd ObjectName;
    OCIInd MethodName;
    OCIInd Flags;
}

struct ODCICost
{
    OCINumber CPUcost;
    OCINumber IOcost;
    OCINumber NetworkCost;
    OCIString* IndexCostInfo;
}

struct ODCICost_ind
{
    OCIInd atomic;
    OCIInd CPUcost;
    OCIInd IOcost;
    OCIInd NetworkCost;
    OCIInd IndexCostInfo;
}

struct ODCIArgDesc
{
    OCINumber ArgType;
    OCIString* TableName;
    OCIString* TableSchema;
    OCIString* ColName;
    OCIString* TablePartitionLower;
    OCIString* TablePartitionUpper;
    OCINumber Cardinality;
}

struct ODCIArgDesc_ind
{
    OCIInd atomic;
    OCIInd ArgType;
    OCIInd TableName;
    OCIInd TableSchema;
    OCIInd ColName;
    OCIInd TablePartitionLower;
    OCIInd TablePartitionUpper;
    OCIInd Cardinality;
}

struct ODCIStatsOptions
{
    OCINumber Sample;
    OCINumber Options;
    OCINumber Flags;
}

struct ODCIStatsOptions_ind
{
    OCIInd atomic;
    OCIInd Sample;
    OCIInd Options;
    OCIInd Flags;
}

struct ODCIEnv
{
    OCINumber EnvFlags;
    OCINumber CallProperty;
    OCINumber DebugLevel;
    OCINumber CursorNum;
}

struct ODCIEnv_ind
{
    OCIInd _atomic;
    OCIInd EnvFlags;
    OCIInd CallProperty;
    OCIInd DebugLevel;
    OCIInd CursorNum;
}

struct ODCIPartInfo
{
    OCIString* TablePartition;
    OCIString* IndexPartition;
    OCINumber IndexPartitionIden;
    OCINumber PartOp;
}

struct ODCIPartInfo_ind
{
    OCIInd atomic;
    OCIInd TablePartition;
    OCIInd IndexPartition;
    OCIInd IndexPartitionIden;
    OCIInd PartOp;
}

/*---------- External Tables ----------*/
struct ODCIExtTableInfo
{
    OCIString* TableSchema;
    OCIString* TableName;
    ODCIColInfoList* RefCols;
    OCIClobLocator* AccessParmClob;
    OCIBlobLocator* AccessParmBlob;
    ODCIArgDescList* Locations;
    ODCIArgDescList* Directories;
    OCIString* DefaultDirectory;
    OCIString* DriverType;
    OCINumber OpCode;
    OCINumber AgentNum;
    OCINumber GranuleSize;
    OCINumber Flag;
    OCINumber SamplePercent;
    OCINumber MaxDoP;
    OCIRaw* SharedBuf;
    OCIString* MTableName;
    OCIString* MTableSchema;
    OCINumber TableObjNo;
}

struct ODCIExtTableInfo_ind
{
    OCIInd _atomic;
    OCIInd TableSchema;
    OCIInd TableName;
    OCIInd RefCols;
    OCIInd AccessParmClob;
    OCIInd AccessParmBlob;
    OCIInd Locations;
    OCIInd Directories;
    OCIInd DefaultDirectory;
    OCIInd DriverType;
    OCIInd OpCode;
    OCIInd AgentNum;
    OCIInd GranuleSize;
    OCIInd Flag;
    OCIInd SamplePercent;
    OCIInd MaxDoP;
    OCIInd SharedBuf;
    OCIInd MTableName;
    OCIInd MTableSchema;
    OCIInd TableObjNo;
}

struct ODCIExtTableQCInfo
{
    OCINumber NumGranules;
    OCINumber NumLocations;
    ODCIGranuleList* GranuleInfo;
    OCINumber IntraSourceConcurrency;
    OCINumber MaxDoP;
    OCIRaw* SharedBuf;
}

struct ODCIExtTableQCInfo_ind
{
    OCIInd _atomic;
    OCIInd NumGranules;
    OCIInd NumLocations;
    OCIInd GranuleInfo;
    OCIInd IntraSourceConcurrency;
    OCIInd MaxDoP;
    OCIInd SharedBuf;
}

/*********************************************************/
/* Table Function Info types (used by ODCITablePrepare)  */
/*********************************************************/

struct ODCITabFuncInfo
{
    ODCINumberList* Attrs;
    OCIType_* RetType;
}

struct ODCITabFuncInfo_ind
{
    OCIInd _atomic;
    OCIInd Attrs;
    OCIInd RetType;
}

/*********************************************************************/
/* Table Function Statistics types (used by ODCIStatsTableFunction)  */
/*********************************************************************/

struct ODCITabFuncStats
{
    OCINumber num_rows;
}

struct ODCITabFuncStats_ind
{
    OCIInd _atomic;
    OCIInd num_rows;
}

/*---------------------------------------------------------------------------
                     PRIVATE TYPES AND CONSTANTS
  ---------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------
                           PUBLIC FUNCTIONS
  ---------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------
                          PRIVATE FUNCTIONS
  ---------------------------------------------------------------------------*/

/* ODCI_ORACLE */
