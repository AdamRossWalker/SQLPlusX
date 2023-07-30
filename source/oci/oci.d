module oci;

/* Copyright (c) 1995, 2010, Oracle and/or its affiliates.
All rights reserved. */

extern (C):

/*
   NAME
     oci.h - V8 Oracle Call Interface public definitions

   DESCRIPTION
     This file defines all the constants and structures required by a V8
     OCI programmer.

   RELATED DOCUMENTS
     V8 OCI Functional Specification
     Oracle Call Interface Programmer's Guide Vol 1 and 2

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
     None

   PRIVATE FUNCTION(S)
     None

   EXAMPLES

   NOTES


   MODIFIED   (MM/DD/YY)
   mbastawa    03/15/10 - add OCI_FETCH_RESERVED_6
   ebatbout    12/28/09 - 8465341: Add OCI_ATTR_DIRPATH_RESERVED_22
   ssahu       04/15/09 - Add user handle as an attribute to session pool
                          handle
   dalpern     03/17/09 - bug 7646876: applying_crossedition_trigger
   kneel       11/21/08 - bump OCI version to 11.2
   thoang      09/24/08 - include ocixstream.h
   asohi       08/25/08 - Bug 7320582 : AQ dequeue navigation flags fix
   thoang      08/04/08 - Add XStream attributes
   msowdaga    07/23/08 - Add flag OCI_SESSGET_SYSDBA
   rphillip    03/21/08 - Add partition memory attribute
   nikeda      04/15/08 - Support OCIP_ATTR_CONTYPE
   mbastawa    12/24/07 - add server, envhp attributes
   slynn       03/18/08 -
   amullick    02/11/08 - add support for OCILobGet/SetContentType
   tbhosle     01/07/08 - add OCI_ATTR_SUBSCR_IPADDR
   nikeda      12/19/07 - Add OCI_SUBSCR_QOS_HAREG
   rphillip    10/22/07 - Add OCI_ATTR_DIRPATH_NO_INDEX_ERRORS
   debanerj    12/14/07 - Added OCI_ATTR_RESERVED_38 and OCI_ATTR_RESERVED_39
   umabhat     09/20/07 - bug6119750 added OCI_FNCODE_APPCTXSET &
                          OCI_FNCODE_APPCTXCLEARALL
   debanerj    04/10/07 - XDS Attributes
   msakayed    05/24/07 - Bug #5095734: add OCI_ATTR_DIRPATH_RESERVED_19
   schoi       03/02/07 - Get/SetOptions API change
   ebatbout    03/30/07 - 5598333: Add OCI_ATTR_DIRPATH_RESERVED_18
   nikeda      03/21/07 - Add OCI_ATTR_RESERVED_37
   abande      03/06/07 - Remove attributes for global stmt cache and
                          metadata cache
   rphillip    02/20/07 - Add OCI_ATTR_DIRPATH_RESERVED_17
   shan        11/16/06 - bug 5595911.
   msakayed    12/04/06 - Bug #5660845: add OCI_DIRPATH_INPUT_OCI
   gviswana    10/26/06 - Remove OCI_ATTR_CURRENT_EDITION
   maramali    09/29/06 - bug 5568492, added OCI_NLS_LOCALE_A2_ISO_2_ORA
   gviswana    09/29/06 - CURRENT_EDITION -> EDITION
   aramappa    09/20/06 - Update major and minor version information
   slynn       07/28/06 - Migrate to new 11g LOB terminiology
   debanerj    07/20/06 - Add OCI_ATTR_LOBPREFETCH_LENGTH
   mbastawa    06/25/06 - add OCI_ATTR_RESERVED_36
   hqian       05/22/06 - 11gR1 proj-18303: add OCI_SYSASM
   dkogan      04/06/06 - disable charset validation by default
   jhealy      05/15/06 - Add TimesTen OCI adapter.
   slynn       06/20/06 - GetSharedRegions
   rthammai    06/13/06 - add reserved attribute
   msakayed    06/15/06 - Project 20586: interval partitioning support
   debanerj    10/25/05 - LOB prefetch
   slynn       05/25/06 - New NG Lob Functionality.
   yujwang     05/16/06 - Add OCI_ATTR_RESERVED_33, OCI_ATTR_RESERVED_34
   abande      04/25/06 - 18297: Add attributes for global stmt cache and
                          metadata cache
   ssvemuri    04/26/06 - Constants for Query Notification support
   jgiloni     05/05/06 - Add OCI_ATCH_RESERVED_7
   mxyang      02/01/06 - Added OCI_ATTR_CURRENT_EDITION attribute
   hqian       05/04/06 - new runtime capability attribute for asm volume
   nikeda      06/06/06 - OCI_TT: Add new OCIP attributes
   aramappa    04/17/06 - Added OCI_FNCODE_ARRAYDESCRIPTORALLOC and
                          OCI_FNCODE_ARRAYDESCRIPTORFREE
   debanerj    05/04/06 - 18313: OCI Net Fusion
   rupsingh    05/26/06 -
   jacao       05/11/06 -
   absaxena    04/17/06 - add notification grouping attributes
   rpingte     02/02/06 - add OCI_ATCH_RESERVED_6
   rpingte     04/27/06 - Add OCI_ATTR_DRIVER_NAME
   jawilson    02/14/06 - add OCI_FNCODE_AQENQSTREAM
   kneel       04/03/06 - Adding support in kjhn for critical severity
   rphillip    03/31/06 - Add OCI_ATTR_DIRPATH_RESERVED_14
   mxyang      02/01/06 - Added OCI_ATTR_APPLICATION_EDITION attribute
   rphillip    01/30/06 - Add new DPAPI attrs
   ebatbout    11/03/05 - Add direct path support for multiple subtypes
   porangas    02/22/06 - 5055398: Define OCI_STMT_CALL
   mbastawa    01/31/06 - add OCI_ATTR_RESERVED_26
   yohu        01/27/06 - align Execution Modes macros
   sjanardh    01/25/06 - add OCI_EXEC_RESERVED_6
   sichandr    01/18/06 - add OCI_ATTR_XMLTYPE_BINARY_XML
   yohu        12/22/05 - add OCI_TRANS_PROMOTE
   srseshad    09/12/05 - stmtcache: callback
   krajan      10/25/05 - Added ENABLE_BEQUEATH attach flag
   mbastawa    09/16/05 - dbhygiene
   porangas    07/20/04 - 1175350: adding attribute for ognfd
   chliang     06/30/05 - add OCI_SUPPRESS_NLS_VALIDATION mode
   aahluwal    03/15/05 - [Bug 4235014]:add ASM, Preconnect events
   ssappara    08/12/04 - Bug3669429 add OCI_ATTR_DESC_SYNBAS
   absaxena    03/24/05 - remove OCI_AQ_RESERVED_5
   mbastawa    03/01/05 - add OCI_EXEC_RESERVED_5
   msakayed    02/15/05 - Bug #3147299: Add OCI_ATTR_CURRENT_ERRCOL
   aahluwal    01/11/05 - [Bug 3944589]: add OCI_AUTH_RESERVED_5
   nikeda      11/15/04 - Add OCIP_IIO
   rvissapr    11/10/04 - bug 3843644 - isencrypted
   hohung      11/22/04 - add OCI_BIND_RESERVED_3
   cchui       10/25/04 - add OCI_ATTR_PROXY_CLIENT
   aahluwal    09/27/04 - add incarnation, reason, cardinality to event handle
   msakayed    09/14/04 - column encryption support (project id 5578)
   jacao       08/17/04 - Add OCI_ATTR_DB_CHARSET_ID
   mhho        08/29/04 - resolve conflicting mode declaration
   sgollapu    05/28/04 - Add OCI_AUTH_RESERVED_3
   mbastawa    08/05/04 - add OCI_ATTR_RESERVED_21
   ebatbout    07/27/04 - add OCI_ATTR_DIRPATH_RESERVED_9 and move all direct
                          path attributes into a separate area in this file.
   clei        06/29/04 - add OCI_ATTR_ENCC_SIZE
   weiwang     05/06/04 - add OCIAQListenOpts and OCIAQLisMsgProps
   weiwang     04/30/04 - add OCI_AQ_RESERVED_5
   nbhatt      04/27/04 - add new attribute
   ssvemuri    06/19/04 -  change notification descriptors and attributes
   ksurlake    06/01/04 - grabtrans 'ksurlake_txn_skmishra_clone'
   ksurlake    05/13/04 - add subscriber handle attributes
   mbastawa    06/01/04 - add 3 more OCI_FETCH_RESERVED modes
   chliang     05/28/04 - add nchar literal replacement modes
   nikeda      05/14/04 - [OLS on RAC] new authentication mode
   debanerj    05/17/04 - 13064: add fncodes for LOB array Read and Write
   nikeda      05/20/04 - [OCI Events] Add incarnation, cardinality,reason
   nikeda      05/18/04 - [OCI Events] Add OCI_ATTR_SERVICENAME
   nikeda      05/17/04 - Add event handle
   nikeda      05/13/04 - [OCI Events] Rename HACBK->EVTCBK, HACTX->EVTCTX
   nikeda      05/10/04 - [OCI Events] code review changes
   nikeda      04/15/04 - [OCI Events] OCI_SESSRLS_DROPSESS_FORCE
   nikeda      04/12/04 - [OCI Events] Add OCI_ATTR_USER_MEMORY
   aahluwal    04/12/04 - add OCI_HNDLFR_RESERVED5
   vraja       04/28/04 - add options for redo sync on commit
   aahluwal    05/29/04 - [OCI Events]: add support for svc, svc member events
   nikeda      05/28/04 - grabtrans 'nikeda_oci_events_copy'
   nikeda      05/18/04 - [OCI Events] Add OCI_ATTR_SERVICENAME
   nikeda      05/17/04 - Add event handle
   nikeda      05/13/04 - [OCI Events] Rename HACBK->EVTCBK, HACTX->EVTCTX
   nikeda      05/10/04 - [OCI Events] code review changes
   nikeda      04/15/04 - [OCI Events] OCI_SESSRLS_DROPSESS_FORCE
   nikeda      04/12/04 - [OCI Events] Add OCI_ATTR_USER_MEMORY
   aahluwal    04/12/04 - add OCI_HNDLFR_RESERVED5
   jciminsk    04/28/04 - merge from RDBMS_MAIN_SOLARIS_040426
   jacao       03/06/04 - add OCI_ATTR_CURRENT_SCHEMA
   aahluwal    01/20/04 - remove OCI_KEEP_FETCH_STATE
   aahluwal    03/25/04 - [OCI Events] add OCI_HTYPE_HAEVENT and related attrs
   nikeda      03/19/04 - [OCI Events] Add OCI_ATTR_HACBK and OCI_ATTR_HACTX
   dfrumkin    12/04/03 - Add database startup/shutdown
   chliang     12/22/03 - grid/main merge: add OCI_ATTR_RESERVED_20
   jciminsk    12/12/03 - merge from RDBMS_MAIN_SOLARIS_031209
   sgollapu    09/19/03 - Add fetch modes
   sgollapu    07/30/03 - Add TSM attributes
   sgollapu    06/26/03 - Add OCI_MUTEX_TRY
   aime        06/23/03 - sync grid with main
   sgollapu    06/07/03 - Add reserved attribute
   sgollapu    06/05/03 - Add reserved auth flag
   rpingte     05/22/03 - Add OCI_ATCH_RESERVED_5
   sgollapu    05/06/03 - Add TSM attributes
   sgollapu    04/10/03 - Session migration Flags/interfaces
   dfrumkin    04/23/04 - add OCI_PREP2_RESERVED_1
   rpingte     05/06/04 - add major and minor version information
   bsinha      04/06/04 - add new OCI_TRANS flag
   chliang     11/26/03 - add OCI_ATTR_RESERVED_19
   preilly     10/23/03 - Make OCI_ATTR_DIRPATH_METADATA_BUF private
   chliang     08/07/03 - add OCI_ATTR_SKIP_BUFFER
   srseshad    03/12/03 - convert public oci api to ansi
   weiwang     05/14/03 - remove iot creation for rule sets
   rkoti       04/15/03 - [2746515] add fntcodes for Unlimited size LOB 6003
   tcruanes    05/13/03 - add slave SQL OCI execution mode
   rkoti       02/21/03 - [2761455] add OCI_FNCODE_AQENQARRAY,
                          OCI_FNCODE_AQDEQARRAY and update OCI_FNCODE_MAXFCN
   tkeefe      01/29/03 - bug-2773794: Add new interface for setting Kerb attrs
   aahluwal    02/06/03 - add OCI_ATTR_TRANSFORMATION_NO
   weiwang     12/05/02 - add OCI_ATTR_USER_PROPERTY
   ataracha    01/03/03 - include ocixmldb.h
   preilly     12/05/02 - Add wait attribute for locking when using dir path
   tkeefe      01/03/03 - bug-2623771: Added OCI_ATTR_KERBEROS_KEY
   lchidamb    12/13/02 - end-to-end tracing attributes
   msakayed    10/28/02 - Bug #2643907: add OCI_ATTR_DIRPATH_SKIPINDEX_METHOD
   rphillip    11/13/02 - Add OCIP_ATTR_DIRPATH_INDEX
   sagrawal    10/13/02 - liniting
   sagrawal    10/03/02 - PL/SQL Compiler warnings
   jstenois    11/07/02 - remove ocixad.h
   chliang     10/21/02 - add OCI_ATTR_RESERVED_16,17
   hsbedi      10/30/02 - grabtrans 'jstenois_fix_xt_convert'
   aahluwal    10/12/02 - add OCI_ATTR_AQ_NUM_E_ERRORS/OCI_ATTR_AQ_ERROR_INDEX
   bdagevil    10/21/02 - add SQL analyze internal exec mode
   csteinba    10/11/02 - add OCI_ATTR_RESERVED_16
   chliang     10/12/02 - add bind row callback attributes
   preilly     10/25/02 - Add new reserved parameters
   tkeefe      10/31/02 - bug-2623771: Added OCI_ATTR_AUDIT_SESSION_ID
   csteinba    10/04/02 - Add OCI_ATTR_RESERVED_15
   mhho        10/11/02 - add new credential constant
   thoang      09/25/02 - Add OCI_XMLTYPE_CREATE_CLOB
   skaluska    10/07/02 - describe rules objects
   csteinba    09/16/02 - Remove OCI_CACHE
   gtarora     10/03/02 - OCI_ATTR_COL_SUBS => OCI_ATTR_OBJ_SUBS
   msakayed    09/09/02 - Bug #2482469: add OCI_ATTR_DIRPATH_RESERVED_[3-6]
   aahluwal    08/30/02 - adding dequeue across txn group
   srseshad    04/24/02 - Add attribute OCI_ATTR_SPOOL_STMTCACHESIZE.
   ebatbout    07/22/02 - Remove OCI_ATTR_RESERVED_11.
   abande      01/17/02 - Bug 1788921; Add external attribute.
   aahluwal    06/04/02 - bug 2360115
   pbagal      05/24/02 - Incorporate review comments
   pbagal      05/22/02 - Introduce instance type attribute.
   whe         07/01/02 - add OCI_BIND_DEFINE_SOFT flags
   gtarora     07/01/02 - Add OCI_ATTR_COL_SUBS
   tkeefe      05/30/02 - Add support for new proxy authentication credentials
   dgprice     12/18/01 - bug 2102779 add reserved force describe
   schandir    11/19/01 - add/modify modes.
   schandir    11/15/01 - add OCI_SPC_STMTCACHE.
   schandir    12/06/01 - change mode value of OCI_SPOOL.
   msakayed    11/02/01 - Bug #2094292: add OCI_ATTR_DIRPATH_INPUT
   dsaha       11/09/01 - add OCI_DTYPE_RESERVED1
   skabraha    11/05/01 - new method flag
   skabraha    10/25/01 - another flag for XML
   skabraha    10/11/01 - describe flags for subtypes
   nbhatt      09/18/01 - new reserved AQ flags
   celsbern    10/19/01 - merge LOG to MAIN
   ksurlake    10/12/01 - add OCI_ATTR_RESERVED_13
   ksurlake    08/13/01 - add OCI_ATTR_RESERVED_12
   schandir    09/24/01 - Adding stmt caching
   abande      09/04/01 - Adding session pooling
   sagrawal    10/23/01 - add new bit for OCIPHandleFree
   preilly     10/25/01 - Add support for specifying metadata on DirPathCtx
   skabraha    09/24/01 - describe flags for XML type
   schandir    09/24/01 - Adding stmt caching
   abande      09/04/01 - Adding session pooling
   stakeda     09/17/01 - add OCI_NLS_CHARSET_ID
   whe         09/19/01 - add OCIXMLType create options
   rpingte     09/11/01 - add OCI_MUTEX_ENV_ONLY and OCI_NO_MUTEX_STMT
   cmlim       08/28/01 - mod datecache attrs to use same naming as dpapi attrs
   wzhang      08/24/01 - Add new keywords for OCINlsNameMap.
   rphillip    05/02/01 - Add date cache attributes
   rphillip    08/22/01 - Add new stream version
   ebatbout    04/13/01 - add definition, OCI_ATTR_RESERVED_11
   chliang     04/12/01 - add shortnames for newer oci funcation
   wzhang      04/11/01 - Add new OCI NLS constants.
   cmlim       04/13/01 - remove attrs not used by dpapi (151 & 152 avail)
   rkambo      03/23/01 - bugfix 1421793
   cmlim       04/02/01 - remove OCI_ATTR_DIRPATH_{NESTED_TBL, SUBST_OBJ_TBL}
                        - note: attribute #s 186 & 205 available
   whe         03/28/01 - add OCI_AFC_PAD_ON/OFF mode
   preilly     03/05/01 - Add stream versioning support to DirPath context
   schandir    12/18/00 - remove attr CONN_INCR_DELAY.
   schandir    12/12/00 - change mode from OCI_POOL to OCI_CPOOL.
   cbarclay    01/12/01 - add atribute for OCIP_ATTR_TMZ
   whe         01/07/01 - add attributes related to UTF16 env mode
   slari       12/29/00 - add blank line
   slari       12/28/00 - OCI_ATTR_RESERVED_10
   whe         12/19/00 - add OCI_ENVCR_RESERVED3
   rpang       11/29/00 - Added OCI_ATTR_ORA_DEBUG_JDWP attribute
   cmlim       11/28/00 - support substitutable object tables in dpapi
   akatti      10/09/00 - [198379]:add OCIRowidToChar
   sgollapu    10/11/00 - Add OCI_PREP_RESERVED_1
   sgollapu    08/27/00 - add attribute to get erroneous column
   sgollapu    07/29/00 - Add snapshot attributes
   kmohan      09/18/00 - add OCI_FNCODE_LOGON2
   abrumm      10/08/00 - include ocixad.h
   mbastawa    10/04/00 - add OCI_ATTR_ROWS_FETCHED
   nbhatt      08/24/00 - add transformation attribute
   dmwong      08/22/00 - OCI_ATTR_CID_VALUE -> OCI_ATTR_CLIENT_IDENTIFIER.
   cmlim       08/30/00 - add OCI_ATTR_DIRPATH_SID
   dsaha       08/18/00 - add OCI_ATTR_RESERVED_5
   amangal     08/17/00 - Merge into 8.2 : 1194361
   slari       08/03/00 - add OCI_ATTR_HANDLE_POSITION
   dsaha       07/20/00 - 2rt exec
   sgollapu    07/04/00 - Add virtual session flag
   cmlim       07/07/00 - add OCI_ATTR_DIRPATH_OID, OCI_ATTR_DIRPATH_NESTED_TBL
   etucker     07/28/00 - add OCIIntervalFromTZ
   rwessman    06/26/00 - N-tier: added new credential attributes
   whe         07/27/00 - add OCI_UTF16 mode
   vjayaram    07/18/00 - add connection pooling changes
   etucker     07/12/00 - add dls apis
   cmlim       07/07/00 - add OCI_ATTR_DIRPATH_OID, OCI_ATTR_DIRPATH_NESTED_TBL
   sgollapu    07/04/00 - Add virtual session flag
   najain      05/01/00 - AQ Signature support
   sgollapu    06/14/00 - Add reserved OCI mode
   rkambo      06/08/00 - notification presentation support
   sagrawal    06/04/00 - ref cursor to c
   ksurlake    06/07/00 - define OCI_POOL
   mbastawa    06/05/00 - added scrollable cursor attributes
   weiwang     03/31/00 - add LDAP support
   whe         05/30/00 - add OCI_ATTR_MAXCHAR_SIZE
   whe         05/23/00 - validate OCI_NO_CACHE mode
   dsaha       02/02/00 - Add no-cache attr in statement handle
   whe         05/23/00 - add OCIP_ICACHE
   allee       05/17/00 - describe support for JAVA implmented TYPE
   preilly     05/30/00 - Continue adding support for objects in direct path lo
   cmlim       05/16/00 - 8.2 dpapi support of ADTs
   rxgovind    05/04/00 - OCIAnyDataSet changes
   rkasamse    05/25/00 - add OCIAnyDataCtx
   rmurthy     04/26/00 - describe support for inheritance
   ksurlake    04/18/00 - Add credential type
   whe         05/24/00 - add OCI_ATTR_CHAR_ attrs
   rkambo      04/19/00 - subscription enhancement
   rmurthy     04/26/00 - describe support for inheritance
   delson      03/28/00 - add OCI_ATTR_RESERVED_2
   abrumm      03/31/00 - external table support
   rkasamse    03/13/00 - add declarations for OCIAnyData
   najain      02/24/00 - support for dequeue as select
   dsaha       03/10/00 - Add OCI_ALWAYS_BLOCKING
   esoyleme    04/25/00 - separated transactions
   sgollapu    12/23/99 - OCIServerAttach extensions
   slari       08/23/99 - add OCI_DTYPE_UCB
   slari       08/20/99 - add OCI_UCBTYPE_REPLACE
   hsbedi      08/31/99 - Memory Stats .
   sgollapu    08/02/99 - oci sql routing
   slari       08/06/99 - rename values for OCI_SERVER_STATUS
   slari       08/02/99 - add OCI_ATTR_SERVER_STATUS
   tnbui       07/28/99 - Remove OCI_DTYPE_TIMESTAMP_ITZ
   amangal     07/19/99 - Merge into 8.1.6 : bug 785797
   tnbui       07/07/99 - Change ADJUSTMENT modes
   dsaha       07/07/99 - OCI_SAHRED_EXT
   dmwong      06/08/99 - add OCI_ATTR_APPCTX_*
   vyanaman    06/23/99 -
   vyanaman    06/21/99 - Add new OCI Datetime and Interval descriptors
   esoyleme    06/29/99 - expose MTS performance enhancements
   rshaikh     04/23/99 - add OCI_SQL_VERSION_*
   tnbui       05/24/99 - Remove OCIAdjStr
   dsaha       05/21/99 - Add OCI_ADJUST_UNK
   mluong      05/17/99 - fix merge
   tnbui       04/05/99 - ADJUSTMENT values
   abrumm      04/16/99 - dpapi: more attributes
   dsaha       02/24/99 - Add OCI_SHOW_DML_WARNINGS
   jiyang      12/07/98 - Add OCI_NLS_DUAL_CURRENCY
   slari       12/07/98 - change OCI_NOMUTEX to OCI_NO_MUTEX
   aroy        11/30/98 - change OCI_NOCALLBACK to OCI_NO_UCB
   aroy        11/13/98 - add env modes to process modes
   slari       09/08/98 - add OCI_FNCODE_SVC2HST and _SVCRH
   aroy        09/04/98 - Add OCI_ATTR_MIGSESSION
   skray       08/14/98 - server groups for session switching
   mluong      08/11/98 - add back OCI_HTYPE_LAST.
   aroy        05/25/98 - add process handle type
   aroy        04/06/98 - add shared mode
   slari       07/13/98 -  merge forward to 8.1.4
   slari       07/09/98 -  add OCI_BIND_RESERVED_2
   slari       07/08/98 -  add OCI_EXACT_FETCH_RESERVED_1
   dsaha       07/07/98 -  Add OCI_PARSE_ONLY
   dsaha       06/29/98 -  Add OCI_PARSE_ONLY
   slari       07/01/98 -  add OCI_BIND_RESERVED_2
   sgollapu    06/25/98 -  Fix bug 683565
   slari       06/17/98 -  remove OC_FETCH_RESERVED_2
   slari       06/11/98 -  add OCI_FETCH_RESERVED_1 and 2
   jhasenbe    05/27/98 -  Remove definitions for U-Calls (Unicode)
   jiyang      05/18/98 - remove OCI_ATTR_CARTLANG
   nbhatt      05/20/98 -  OCI_DEQ_REMOVE_NODATA
   nbhatt      05/19/98 - correct AQ opcode
   skmishra    05/06/98 - Add precision attribute to Attributes list
   aroy        04/20/98 - merge forward 8.0.5 -> 8.1.3
   schandra    05/01/98 - OCI sender id
   sgollapu    02/19/98 - enhanced array DML
   nbhatt      05/15/98 -  AQ listen call
   sgollapu    04/27/98 - more attributes
   skaluska    04/06/98 - Add OCI_PTYPE_SCHEMA, OCI_PTYPE_DATABASE
   slari       04/28/98 - add OCI_ATTR_PDPRC
   lchidamb    05/05/98 - change OCI_NAMESPACE_AQ to 1
   nbhatt      04/27/98 - AQ Notification Descriptor
   abrumm      06/24/98 - more direct path attributes
   abrumm      05/27/98 - OCI direct path interface support
   abrumm      05/08/98 - OCI direct path interface support
   lchidamb    03/02/98 - client notification additions
   kkarun      04/17/98 - Add more Interval functions
   vyanaman    04/16/98 - Add get/set TZ
   kkarun      04/14/98 - Add OCI Datetime shortnames
   vyanaman    04/13/98 - Add OCI DateTime and Interval check error codes
   kkarun      04/07/98 - Add OCI_DTYPE_DATETIME and OCI_DTYPE_INTERVAL
   esoyleme    12/15/97 - support failover callback retry
   esoyleme    04/22/98 - merge support for failover callback retry
   mluong      04/16/98 - add OCI_FNCODE_LOBLOCATORASSIGN
   rkasamse    04/17/98 - add short names for OCIPickler(Memory/Ctx) cart servi
   slari       04/10/98 - add OCI_FNCODE_SVCCTXTOLDA
   slari       04/09/98 - add OCI_FNCODE_RESET
   slari       04/07/98 - add OCI_FNCODE_LOBFILEISOPEN
   slari       04/06/98 - add OCI_FNCODE_LOBOPEN
   slari       03/20/98 - change OCI_CBTYPE_xxx to OCI_UCBTYPE_xxx
   slari       03/18/98 - add OCI_FNCODE_MAXFCN
   slari       02/12/98 - add OCI_ENV_NO_USRCB
   skabraha    04/09/98 - adding shortnames for OCIFile
   rhwu        04/03/98 - Add short names for the OCIThread package
   tanguyen    04/03/98 - add OCI_ATTR_xxxx for type inheritance
   rkasamse    04/02/98 - add OCI_ATTR_UCI_REFRESH
   nramakri    04/01/98 - Add short names for the OCIExtract package
   ewaugh      03/31/98 - Add short names for the OCIFormat package.
   jhasenbe    04/06/98 - Add definitions for U-Calls (Unicode)
                          (OCI_TEXT, OCI_UTEXT, OCI_UTEXT4)
   skmishra    03/03/98 - Add OCI_ATTR_PARSE_ERROR_OFFSET
   rwessman    03/11/98 - Added OCI_CRED_PROXY for proxy authentication
   abrumm      03/31/98 - OCI direct path interface support
   nmallava    03/03/98 - add constants for temp lob apis
   skotsovo    03/05/98 - resolve merge conflicts
   skotsovo    02/24/98 - add OCI_DTYPE_LOC
   skaluska    01/21/98 - Add OCI_ATTR_LTYPE
   rkasamse    01/06/98 - add OCI_ATTR* for obj cache enhancements
   dchatter    01/08/98 - more comments
   skabraha    12/02/97 - moved oci1.h to the front of include files.
   jiyang      12/18/97 - Add OCI_NLS_MAX_BUFSZ
   rhwu        12/02/97 - move oci1.h up
   ewaugh      12/15/97 - Add short names for the OCIFormat package.
   rkasamse    12/02/97 - Add a constant for memory cartridge services -- OCI_M
   nmallava    12/31/97 - open/close for internal lobs
   khnguyen    11/27/97 - add OCI_ATTR_LFPRECISION, OCI_ATTR_FSPRECISION
   rkasamse    11/03/97 - add types for pickler cartridge services
   mluong      11/20/97 - changed ubig_ora to ub4 per skotsovo
   ssamu       11/14/97 - add oci1.h
   jiyang      11/13/97 - Add NLS service for cartridge
   esoyleme    12/15/97 - support failover callback retry
   jwijaya     10/21/97 - change OCILobOffset/Length from ubig_ora to ub4
   cxcheng     07/28/97 - fix compile with SLSHORTNAME
   schandra    06/25/97 - AQ OCI interface
   sgollapu    07/25/97 - Add OCI_ATTR_DESC_PUBLIC
   cxcheng     06/16/97 - add OCI_ATTR_TDO
   skotsovo    06/05/97 - add fntcodes for lob buffering subsystem
   esoyleme    05/13/97 - move failover callback prototype
   skmishra    05/06/97 - stdc compiler fixes
   skmishra    04/22/97 - Provide C++ compatibility
   lchidamb    04/19/97 - add OCI_ATTR_SESSLANG
   ramkrish    04/15/97 - Add OCI_LOB_BUFFER_(NO)FREE
   sgollapu    04/18/97 - Add OCI_ATTR_TABLESPACE
   skaluska    04/17/97 - Add OCI_ATTR_SUB_NAME
   schandra    04/10/97 - Use long OCI names
   aroy        03/27/97 - add OCI_DTYPE_FILE
   sgollapu    03/26/97 - Add OCI_OTYPEs
   skmishra    04/09/97 - Added constant OCI_ROWID_LEN
   dchatter    03/21/97 - add attr OCI_ATTR_IN_V8_MODE
   lchidamb    03/21/97 - add OCI_COMMIT_ON_SUCCESS execution mode
   skmishra    03/20/97 - Added OCI_ATTR_LOBEMPTY
   sgollapu    03/19/97 - Add OCI_ATTR_OVRLD_ID
   aroy        03/17/97 - add postprocessing callback
   sgollapu    03/15/97 - Add OCI_ATTR_PARAM
   cxcheng     02/07/97 - change OCI_PTYPE codes for type method for consistenc
   cxcheng     02/05/97 - add OCI_PTYPE_TYPE_RESULT
   cxcheng     02/04/97 - rename OCI_PTYPE constants to be more consistent
   cxcheng     02/03/97 - add OCI_ATTR, OCI_PTYPE contants for describe type
   esoyleme    01/23/97 - merge neerja callback
   sgollapu    12/30/96 - Remove OCI_DTYPE_SECURITY
   asurpur     12/26/96 - CHanging OCI_NO_AUTH to OCI_AUTH
   sgollapu    12/23/96 - Add more attrs to COL, ARG, and SEQ
   sgollapu    12/12/96 - Add OCI_DESCRIBE_ONLY
   slari       12/11/96 - change prototype of OCICallbackInBind
   nbhatt      12/05/96 - "callback"
   lchidamb    11/19/96 - handle subclassing
   sgollapu    11/09/96 - OCI_PATTR_*
   dchatter    11/04/96 - add attr OCI_ATTR_CHRCNT
   mluong      11/01/96 - test
   cxcheng     10/31/96 - add #defines for OCILobLength etc
   dchatter    10/31/96 - add lob read write call back fp defs
   dchatter    10/30/96 - more changes
   rhari       10/30/96 - Include ociextp.h at the very end
   lchidamb    10/22/96 - add fdo attribute for bind/server handle
   dchatter    10/22/96 - change attr defn for prefetch parameters & lobs/file
                          calls
   slari       10/21/96 - add OCI_ENV_NO_MUTEX
   rhari       10/25/96 - Include ociextp.h
   rxgovind    10/25/96 - add OCI_LOBMAXSIZE, remove OCI_FILE_READWRITE
   sgollapu    10/24/96 - Correct OCILogon and OCILogoff
   sgollapu    10/24/96 - Correct to OCILogon and OCILogoff
   sgollapu    10/21/96 - Add ocilon and ociloff
   skaluska    10/31/96 - Add OCI_PTYPE values
   sgollapu    10/17/96 - correct OCI_ATTR_SVCCTX to OCI_ATTR_SERVER
   rwessman    10/16/96 - Added security functions and fixed olint errors.
   sthakur     10/14/96 - add more COR attributes
   cxcheng     10/14/96 - re-enable LOB functions
   sgollapu    10/10/96 - Add ocibdp and ocibdn
   slari       10/07/96 - add back OCIRowid
   aroy        10/08/96 -  add typedef ocibfill for PRO*C
   mluong      10/11/96 - replace OCI_ATTR_CHARSET* with OCI_ATTR_CHARSET_*
   cxcheng     10/10/96 - temporarily take out #define for lob functions
   sgollapu    10/02/96 - Rename OCI functions and datatypes
   skotsovo    10/01/96 - move orl lob fnts to oci
   aroy        09/10/96 - fix merge errors
   aroy        08/19/96 - NCHAR support
   jboonleu    09/05/96 - add OCI attributes for object cache
   dchatter    08/20/96 - HTYPE ranges from 1-50; DTYPE from 50-255
   slari       08/06/96 - define OCI_DTYPE_ROWID
   sthakur     08/14/96 - complex object support
   schandra    06/17/96 - Convert XA to use new OCI
   abrik       08/15/96 - OCI_ATTR_HEAPALLOC added
   aroy        07/17/96 - terminology change: ocilobd => ocilobl
   aroy        07/03/96 - add lob typedefs for Pro*C
   slari       06/28/96 - add OCI_ATTR_STMT_TYPE
   lchidamb    06/26/96 - reorg #ifndef
   schandra    05/31/96 - attribute types for internal and external client name
   asurpur     05/30/96 - Changing the value of mode
   schandra    05/18/96 - OCI_TRANS_TWOPHASE -> 0x00000001 to 0x00100000
   slari       05/30/96 - add callback function prototypes
   jbellemo    05/23/96 - remove ociisc
   schandra    04/23/96 - loosely-coupled branches
   asurpur     05/15/96 - New mode for ocicpw
   aroy        04/24/96 - making ocihandles opaque
   slari       04/18/96 - add missing defines
   schandra    03/27/96 - V8OCI - add transaction related calls
   dchatter    04/01/96 - add OCI_FILE options
   dchatter    03/21/96 - add oci2lda conversion routines
   dchatter    03/07/96 - add OCI piece definition
   slari       03/12/96 - add describe attributes
   slari       03/12/96 - add OCI_OTYPE_QUERY
   aroy        02/28/96 - Add column attributes
   slari       02/09/96 - add OCI_OBJECT
   slari       02/07/96 - add OCI_HYTPE_DSC
   aroy        01/10/96 - adding function code defines...
   dchatter    01/03/96 - define OCI_NON_BLOCKING
   dchatter    01/02/96 - Add Any descriptor
   dchatter    01/02/96 - Add Select List descriptor
   dchatter    12/29/95 - V8 OCI definitions
   dchatter    12/29/95 - Creation

*/

/*---------------------------------------------------------------------------
 Short names provided for platforms which do not allow extended symbolic names
  ---------------------------------------------------------------------------*/

/* Translation of the long function/type names to short names for IBM only */
/* maybe lint will use this too */

/* OCIThread short name */

/* Translation between the old and new datatypes */

/* ifdef SLSHORTNAME */

import oratypes;
import ocidfn;
import oci1;
import oro;
import ori;
import orl;
import ort;
import ociextp;
import ociapr;
import ociap;
import ocixmldb;
import oci8dp;
import ociextp;
import ocixstream;

/*---------------------------------------------------------------------------
                     PUBLIC TYPES AND CONSTANTS
  ---------------------------------------------------------------------------*/

/*-----------------------------Handle Types----------------------------------*/
/* handle types range from 1 - 49 */
enum OCI_HTYPE_FIRST = 1; /* start value of handle type */
enum OCI_HTYPE_ENV = 1; /* environment handle */
enum OCI_HTYPE_ERROR = 2; /* error handle */
enum OCI_HTYPE_SVCCTX = 3; /* service handle */
enum OCI_HTYPE_STMT = 4; /* statement handle */
enum OCI_HTYPE_BIND = 5; /* bind handle */
enum OCI_HTYPE_DEFINE = 6; /* define handle */
enum OCI_HTYPE_DESCRIBE = 7; /* describe handle */
enum OCI_HTYPE_SERVER = 8; /* server handle */
enum OCI_HTYPE_SESSION = 9; /* authentication handle */
enum OCI_HTYPE_AUTHINFO = OCI_HTYPE_SESSION; /* SessionGet auth handle */
enum OCI_HTYPE_TRANS = 10; /* transaction handle */
enum OCI_HTYPE_COMPLEXOBJECT = 11; /* complex object retrieval handle */
enum OCI_HTYPE_SECURITY = 12; /* security handle */
enum OCI_HTYPE_SUBSCRIPTION = 13; /* subscription handle */
enum OCI_HTYPE_DIRPATH_CTX = 14; /* direct path context */
enum OCI_HTYPE_DIRPATH_COLUMN_ARRAY = 15; /* direct path column array */
enum OCI_HTYPE_DIRPATH_STREAM = 16; /* direct path stream */
enum OCI_HTYPE_PROC = 17; /* process handle */
enum OCI_HTYPE_DIRPATH_FN_CTX = 18; /* direct path function context */
enum OCI_HTYPE_DIRPATH_FN_COL_ARRAY = 19; /* dp object column array */
enum OCI_HTYPE_XADSESSION = 20; /* access driver session */
enum OCI_HTYPE_XADTABLE = 21; /* access driver table */
enum OCI_HTYPE_XADFIELD = 22; /* access driver field */
enum OCI_HTYPE_XADGRANULE = 23; /* access driver granule */
enum OCI_HTYPE_XADRECORD = 24; /* access driver record */
enum OCI_HTYPE_XADIO = 25; /* access driver I/O */
enum OCI_HTYPE_CPOOL = 26; /* connection pool handle */
enum OCI_HTYPE_SPOOL = 27; /* session pool handle */
enum OCI_HTYPE_ADMIN = 28; /* admin handle */
enum OCI_HTYPE_EVENT = 29; /* HA event handle */

enum OCI_HTYPE_LAST = 29; /* last value of a handle type */

/*---------------------------------------------------------------------------*/

/*-------------------------Descriptor Types----------------------------------*/
/* descriptor values range from 50 - 255 */
enum OCI_DTYPE_FIRST = 50; /* start value of descriptor type */
enum OCI_DTYPE_LOB = 50; /* lob  locator */
enum OCI_DTYPE_SNAP = 51; /* snapshot descriptor */
enum OCI_DTYPE_RSET = 52; /* result set descriptor */
enum OCI_DTYPE_PARAM = 53; /* a parameter descriptor obtained from ocigparm */
enum OCI_DTYPE_ROWID = 54; /* rowid descriptor */
enum OCI_DTYPE_COMPLEXOBJECTCOMP = 55;
/* complex object retrieval descriptor */
enum OCI_DTYPE_FILE = 56; /* File Lob locator */
enum OCI_DTYPE_AQENQ_OPTIONS = 57; /* enqueue options */
enum OCI_DTYPE_AQDEQ_OPTIONS = 58; /* dequeue options */
enum OCI_DTYPE_AQMSG_PROPERTIES = 59; /* message properties */
enum OCI_DTYPE_AQAGENT = 60; /* aq agent */
enum OCI_DTYPE_LOCATOR = 61; /* LOB locator */
enum OCI_DTYPE_INTERVAL_YM = 62; /* Interval year month */
enum OCI_DTYPE_INTERVAL_DS = 63; /* Interval day second */
enum OCI_DTYPE_AQNFY_DESCRIPTOR = 64; /* AQ notify descriptor */
enum OCI_DTYPE_DATE = 65; /* Date */
enum OCI_DTYPE_TIME = 66; /* Time */
enum OCI_DTYPE_TIME_TZ = 67; /* Time with timezone */
enum OCI_DTYPE_TIMESTAMP = 68; /* Timestamp */
enum OCI_DTYPE_TIMESTAMP_TZ = 69; /* Timestamp with timezone */
enum OCI_DTYPE_TIMESTAMP_LTZ = 70; /* Timestamp with local tz */
enum OCI_DTYPE_UCB = 71; /* user callback descriptor */
enum OCI_DTYPE_SRVDN = 72; /* server DN list descriptor */
enum OCI_DTYPE_SIGNATURE = 73; /* signature */
enum OCI_DTYPE_RESERVED_1 = 74; /* reserved for internal use */
enum OCI_DTYPE_AQLIS_OPTIONS = 75; /* AQ listen options */
enum OCI_DTYPE_AQLIS_MSG_PROPERTIES = 76; /* AQ listen msg props */
enum OCI_DTYPE_CHDES = 77; /* Top level change notification desc */
enum OCI_DTYPE_TABLE_CHDES = 78; /* Table change descriptor           */
enum OCI_DTYPE_ROW_CHDES = 79; /* Row change descriptor            */
enum OCI_DTYPE_CQDES = 80; /* Query change descriptor */
enum OCI_DTYPE_LOB_REGION = 81; /* LOB Share region descriptor */
enum OCI_DTYPE_LAST = 81; /* last value of a descriptor type */

/*---------------------------------------------------------------------------*/

/*--------------------------------LOB types ---------------------------------*/
enum OCI_TEMP_BLOB = 1; /* LOB type - BLOB ------------------ */
enum OCI_TEMP_CLOB = 2; /* LOB type - CLOB ------------------ */
/*---------------------------------------------------------------------------*/

/*-------------------------Object Ptr Types----------------------------------*/
enum OCI_OTYPE_NAME = 1; /* object name */
enum OCI_OTYPE_REF = 2; /* REF to TDO */
enum OCI_OTYPE_PTR = 3; /* PTR to TDO */
/*---------------------------------------------------------------------------*/

/*=============================Attribute Types===============================*/
/*
   Note: All attributes are global.  New attibutes should be added to the end
   of the list. Before you add an attribute see if an existing one can be
   used for your handle.

   If you see any holes please use the holes first.

*/
/*===========================================================================*/

enum OCI_ATTR_FNCODE = 1; /* the OCI function code */
enum OCI_ATTR_OBJECT = 2; /* is the environment initialized in object mode */
enum OCI_ATTR_NONBLOCKING_MODE = 3; /* non blocking mode */
enum OCI_ATTR_SQLCODE = 4; /* the SQL verb */
enum OCI_ATTR_ENV = 5; /* the environment handle */
enum OCI_ATTR_SERVER = 6; /* the server handle */
enum OCI_ATTR_SESSION = 7; /* the user session handle */
enum OCI_ATTR_TRANS = 8; /* the transaction handle */
enum OCI_ATTR_ROW_COUNT = 9; /* the rows processed so far */
enum OCI_ATTR_SQLFNCODE = 10; /* the SQL verb of the statement */
enum OCI_ATTR_PREFETCH_ROWS = 11; /* sets the number of rows to prefetch */
enum OCI_ATTR_NESTED_PREFETCH_ROWS = 12; /* the prefetch rows of nested table*/
enum OCI_ATTR_PREFETCH_MEMORY = 13; /* memory limit for rows fetched */
enum OCI_ATTR_NESTED_PREFETCH_MEMORY = 14; /* memory limit for nested rows */
enum OCI_ATTR_CHAR_COUNT = 15;
/* this specifies the bind and define size in characters */
enum OCI_ATTR_PDSCL = 16; /* packed decimal scale */
enum OCI_ATTR_FSPRECISION = OCI_ATTR_PDSCL;
/* fs prec for datetime data types */
enum OCI_ATTR_PDPRC = 17; /* packed decimal format */
enum OCI_ATTR_LFPRECISION = OCI_ATTR_PDPRC;
/* fs prec for datetime data types */
enum OCI_ATTR_PARAM_COUNT = 18; /* number of column in the select list */
enum OCI_ATTR_ROWID = 19; /* the rowid */
enum OCI_ATTR_CHARSET = 20; /* the character set value */
enum OCI_ATTR_NCHAR = 21; /* NCHAR type */
enum OCI_ATTR_USERNAME = 22; /* username attribute */
enum OCI_ATTR_PASSWORD = 23; /* password attribute */
enum OCI_ATTR_STMT_TYPE = 24; /* statement type */
enum OCI_ATTR_INTERNAL_NAME = 25; /* user friendly global name */
enum OCI_ATTR_EXTERNAL_NAME = 26; /* the internal name for global txn */
enum OCI_ATTR_XID = 27; /* XOPEN defined global transaction id */
enum OCI_ATTR_TRANS_LOCK = 28; /* */
enum OCI_ATTR_TRANS_NAME = 29; /* string to identify a global transaction */
enum OCI_ATTR_HEAPALLOC = 30; /* memory allocated on the heap */
enum OCI_ATTR_CHARSET_ID = 31; /* Character Set ID */
enum OCI_ATTR_CHARSET_FORM = 32; /* Character Set Form */
enum OCI_ATTR_MAXDATA_SIZE = 33; /* Maximumsize of data on the server  */
enum OCI_ATTR_CACHE_OPT_SIZE = 34; /* object cache optimal size */
enum OCI_ATTR_CACHE_MAX_SIZE = 35; /* object cache maximum size percentage */
enum OCI_ATTR_PINOPTION = 36; /* object cache default pin option */
enum OCI_ATTR_ALLOC_DURATION = 37;
/* object cache default allocation duration */
enum OCI_ATTR_PIN_DURATION = 38; /* object cache default pin duration */
enum OCI_ATTR_FDO = 39; /* Format Descriptor object attribute */
enum OCI_ATTR_POSTPROCESSING_CALLBACK = 40;
/* Callback to process outbind data */
enum OCI_ATTR_POSTPROCESSING_CONTEXT = 41;
/* Callback context to process outbind data */
enum OCI_ATTR_ROWS_RETURNED = 42;
/* Number of rows returned in current iter - for Bind handles */
enum OCI_ATTR_FOCBK = 43; /* Failover Callback attribute */
enum OCI_ATTR_IN_V8_MODE = 44; /* is the server/service context in V8 mode */
enum OCI_ATTR_LOBEMPTY = 45; /* empty lob ? */
enum OCI_ATTR_SESSLANG = 46; /* session language handle */

enum OCI_ATTR_VISIBILITY = 47; /* visibility */
enum OCI_ATTR_RELATIVE_MSGID = 48; /* relative message id */
enum OCI_ATTR_SEQUENCE_DEVIATION = 49; /* sequence deviation */

enum OCI_ATTR_CONSUMER_NAME = 50; /* consumer name */
enum OCI_ATTR_DEQ_MODE = 51; /* dequeue mode */
enum OCI_ATTR_NAVIGATION = 52; /* navigation */
enum OCI_ATTR_WAIT = 53; /* wait */
enum OCI_ATTR_DEQ_MSGID = 54; /* dequeue message id */

enum OCI_ATTR_PRIORITY = 55; /* priority */
enum OCI_ATTR_DELAY = 56; /* delay */
enum OCI_ATTR_EXPIRATION = 57; /* expiration */
enum OCI_ATTR_CORRELATION = 58; /* correlation id */
enum OCI_ATTR_ATTEMPTS = 59; /* # of attempts */
enum OCI_ATTR_RECIPIENT_LIST = 60; /* recipient list */
enum OCI_ATTR_EXCEPTION_QUEUE = 61; /* exception queue name */
enum OCI_ATTR_ENQ_TIME = 62; /* enqueue time (only OCIAttrGet) */
enum OCI_ATTR_MSG_STATE = 63; /* message state (only OCIAttrGet) */
/* NOTE: 64-66 used below */
enum OCI_ATTR_AGENT_NAME = 64; /* agent name */
enum OCI_ATTR_AGENT_ADDRESS = 65; /* agent address */
enum OCI_ATTR_AGENT_PROTOCOL = 66; /* agent protocol */
enum OCI_ATTR_USER_PROPERTY = 67; /* user property */
enum OCI_ATTR_SENDER_ID = 68; /* sender id */
enum OCI_ATTR_ORIGINAL_MSGID = 69; /* original message id */

enum OCI_ATTR_QUEUE_NAME = 70; /* queue name */
enum OCI_ATTR_NFY_MSGID = 71; /* message id */
enum OCI_ATTR_MSG_PROP = 72; /* message properties */

enum OCI_ATTR_NUM_DML_ERRORS = 73; /* num of errs in array DML */
enum OCI_ATTR_DML_ROW_OFFSET = 74; /* row offset in the array */

/* AQ array error handling uses DML method of accessing errors */
enum OCI_ATTR_AQ_NUM_ERRORS = OCI_ATTR_NUM_DML_ERRORS;
enum OCI_ATTR_AQ_ERROR_INDEX = OCI_ATTR_DML_ROW_OFFSET;

enum OCI_ATTR_DATEFORMAT = 75; /* default date format string */
enum OCI_ATTR_BUF_ADDR = 76; /* buffer address */
enum OCI_ATTR_BUF_SIZE = 77; /* buffer size */

/* For values 78 - 80, see DirPathAPI attribute section in this file */

enum OCI_ATTR_NUM_ROWS = 81; /* number of rows in column array */
/* NOTE that OCI_ATTR_NUM_COLS is a column
 * array attribute too.
 */
enum OCI_ATTR_COL_COUNT = 82; /* columns of column array
   processed so far.       */
enum OCI_ATTR_STREAM_OFFSET = 83; /* str off of last row processed */
enum OCI_ATTR_SHARED_HEAPALLOC = 84; /* Shared Heap Allocation Size */

enum OCI_ATTR_SERVER_GROUP = 85; /* server group name */

enum OCI_ATTR_MIGSESSION = 86; /* migratable session attribute */

enum OCI_ATTR_NOCACHE = 87; /* Temporary LOBs */

enum OCI_ATTR_MEMPOOL_SIZE = 88; /* Pool Size */
enum OCI_ATTR_MEMPOOL_INSTNAME = 89; /* Instance name */
enum OCI_ATTR_MEMPOOL_APPNAME = 90; /* Application name */
enum OCI_ATTR_MEMPOOL_HOMENAME = 91; /* Home Directory name */
enum OCI_ATTR_MEMPOOL_MODEL = 92; /* Pool Model (proc,thrd,both)*/
enum OCI_ATTR_MODES = 93; /* Modes */

enum OCI_ATTR_SUBSCR_NAME = 94; /* name of subscription */
enum OCI_ATTR_SUBSCR_CALLBACK = 95; /* associated callback */
enum OCI_ATTR_SUBSCR_CTX = 96; /* associated callback context */
enum OCI_ATTR_SUBSCR_PAYLOAD = 97; /* associated payload */
enum OCI_ATTR_SUBSCR_NAMESPACE = 98; /* associated namespace */

enum OCI_ATTR_PROXY_CREDENTIALS = 99; /* Proxy user credentials */
enum OCI_ATTR_INITIAL_CLIENT_ROLES = 100; /* Initial client role list */

enum OCI_ATTR_UNK = 101; /* unknown attribute */
enum OCI_ATTR_NUM_COLS = 102; /* number of columns */
enum OCI_ATTR_LIST_COLUMNS = 103; /* parameter of the column list */
enum OCI_ATTR_RDBA = 104; /* DBA of the segment header */
enum OCI_ATTR_CLUSTERED = 105; /* whether the table is clustered */
enum OCI_ATTR_PARTITIONED = 106; /* whether the table is partitioned */
enum OCI_ATTR_INDEX_ONLY = 107; /* whether the table is index only */
enum OCI_ATTR_LIST_ARGUMENTS = 108; /* parameter of the argument list */
enum OCI_ATTR_LIST_SUBPROGRAMS = 109; /* parameter of the subprogram list */
enum OCI_ATTR_REF_TDO = 110; /* REF to the type descriptor */
enum OCI_ATTR_LINK = 111; /* the database link name */
enum OCI_ATTR_MIN = 112; /* minimum value */
enum OCI_ATTR_MAX = 113; /* maximum value */
enum OCI_ATTR_INCR = 114; /* increment value */
enum OCI_ATTR_CACHE = 115; /* number of sequence numbers cached */
enum OCI_ATTR_ORDER = 116; /* whether the sequence is ordered */
enum OCI_ATTR_HW_MARK = 117; /* high-water mark */
enum OCI_ATTR_TYPE_SCHEMA = 118; /* type's schema name */
enum OCI_ATTR_TIMESTAMP = 119; /* timestamp of the object */
enum OCI_ATTR_NUM_ATTRS = 120; /* number of sttributes */
enum OCI_ATTR_NUM_PARAMS = 121; /* number of parameters */
enum OCI_ATTR_OBJID = 122; /* object id for a table or view */
enum OCI_ATTR_PTYPE = 123; /* type of info described by */
enum OCI_ATTR_PARAM = 124; /* parameter descriptor */
enum OCI_ATTR_OVERLOAD_ID = 125; /* overload ID for funcs and procs */
enum OCI_ATTR_TABLESPACE = 126; /* table name space */
enum OCI_ATTR_TDO = 127; /* TDO of a type */
enum OCI_ATTR_LTYPE = 128; /* list type */
enum OCI_ATTR_PARSE_ERROR_OFFSET = 129; /* Parse Error offset */
enum OCI_ATTR_IS_TEMPORARY = 130; /* whether table is temporary */
enum OCI_ATTR_IS_TYPED = 131; /* whether table is typed */
enum OCI_ATTR_DURATION = 132; /* duration of temporary table */
enum OCI_ATTR_IS_INVOKER_RIGHTS = 133; /* is invoker rights */
enum OCI_ATTR_OBJ_NAME = 134; /* top level schema obj name */
enum OCI_ATTR_OBJ_SCHEMA = 135; /* schema name */
enum OCI_ATTR_OBJ_ID = 136; /* top level schema object id */

/* For values 137 - 141, see DirPathAPI attribute section in this file */

enum OCI_ATTR_TRANS_TIMEOUT = 142; /* transaction timeout */
enum OCI_ATTR_SERVER_STATUS = 143; /* state of the server handle */
enum OCI_ATTR_STATEMENT = 144; /* statement txt in stmt hdl */

/* For value 145, see DirPathAPI attribute section in this file */

enum OCI_ATTR_DEQCOND = 146; /* dequeue condition */
enum OCI_ATTR_RESERVED_2 = 147; /* reserved */

enum OCI_ATTR_SUBSCR_RECPT = 148; /* recepient of subscription */
enum OCI_ATTR_SUBSCR_RECPTPROTO = 149; /* protocol for recepient */

/* For values 150 - 151, see DirPathAPI attribute section in this file */

enum OCI_ATTR_LDAP_HOST = 153; /* LDAP host to connect to */
enum OCI_ATTR_LDAP_PORT = 154; /* LDAP port to connect to */
enum OCI_ATTR_BIND_DN = 155; /* bind DN */
enum OCI_ATTR_LDAP_CRED = 156; /* credentials to connect to LDAP */
enum OCI_ATTR_WALL_LOC = 157; /* client wallet location */
enum OCI_ATTR_LDAP_AUTH = 158; /* LDAP authentication method */
enum OCI_ATTR_LDAP_CTX = 159; /* LDAP adminstration context DN */
enum OCI_ATTR_SERVER_DNS = 160; /* list of registration server DNs */

enum OCI_ATTR_DN_COUNT = 161; /* the number of server DNs */
enum OCI_ATTR_SERVER_DN = 162; /* server DN attribute */

enum OCI_ATTR_MAXCHAR_SIZE = 163; /* max char size of data */

enum OCI_ATTR_CURRENT_POSITION = 164; /* for scrollable result sets*/

/* Added to get attributes for ref cursor to statement handle */
enum OCI_ATTR_RESERVED_3 = 165; /* reserved */
enum OCI_ATTR_RESERVED_4 = 166; /* reserved */

/* For value 167, see DirPathAPI attribute section in this file */

enum OCI_ATTR_DIGEST_ALGO = 168; /* digest algorithm */
enum OCI_ATTR_CERTIFICATE = 169; /* certificate */
enum OCI_ATTR_SIGNATURE_ALGO = 170; /* signature algorithm */
enum OCI_ATTR_CANONICAL_ALGO = 171; /* canonicalization algo. */
enum OCI_ATTR_PRIVATE_KEY = 172; /* private key */
enum OCI_ATTR_DIGEST_VALUE = 173; /* digest value */
enum OCI_ATTR_SIGNATURE_VAL = 174; /* signature value */
enum OCI_ATTR_SIGNATURE = 175; /* signature */

/* attributes for setting OCI stmt caching specifics in svchp */
enum OCI_ATTR_STMTCACHESIZE = 176; /* size of the stm cache */

/* --------------------------- Connection Pool Attributes ------------------ */
enum OCI_ATTR_CONN_NOWAIT = 178;
enum OCI_ATTR_CONN_BUSY_COUNT = 179;
enum OCI_ATTR_CONN_OPEN_COUNT = 180;
enum OCI_ATTR_CONN_TIMEOUT = 181;
enum OCI_ATTR_STMT_STATE = 182;
enum OCI_ATTR_CONN_MIN = 183;
enum OCI_ATTR_CONN_MAX = 184;
enum OCI_ATTR_CONN_INCR = 185;

/* For value 187, see DirPathAPI attribute section in this file */

enum OCI_ATTR_NUM_OPEN_STMTS = 188; /* open stmts in session */
enum OCI_ATTR_DESCRIBE_NATIVE = 189; /* get native info via desc */

enum OCI_ATTR_BIND_COUNT = 190; /* number of bind postions */
enum OCI_ATTR_HANDLE_POSITION = 191; /* pos of bind/define handle */
enum OCI_ATTR_RESERVED_5 = 192; /* reserverd */
enum OCI_ATTR_SERVER_BUSY = 193; /* call in progress on server*/

/* For value 194, see DirPathAPI attribute section in this file */

/* notification presentation for recipient */
enum OCI_ATTR_SUBSCR_RECPTPRES = 195;
enum OCI_ATTR_TRANSFORMATION = 196; /* AQ message transformation */

enum OCI_ATTR_ROWS_FETCHED = 197; /* rows fetched in last call */

/* --------------------------- Snapshot attributes ------------------------- */
enum OCI_ATTR_SCN_BASE = 198; /* snapshot base */
enum OCI_ATTR_SCN_WRAP = 199; /* snapshot wrap */

/* --------------------------- Miscellanous attributes --------------------- */
enum OCI_ATTR_RESERVED_6 = 200; /* reserved */
enum OCI_ATTR_READONLY_TXN = 201; /* txn is readonly */
enum OCI_ATTR_RESERVED_7 = 202; /* reserved */
enum OCI_ATTR_ERRONEOUS_COLUMN = 203; /* position of erroneous col */
enum OCI_ATTR_RESERVED_8 = 204; /* reserved */
enum OCI_ATTR_ASM_VOL_SPRT = 205; /* ASM volume supported? */

/* For value 206, see DirPathAPI attribute section in this file */

enum OCI_ATTR_INST_TYPE = 207; /* oracle instance type */
/******USED attribute 208 for  OCI_ATTR_SPOOL_STMTCACHESIZE*******************/

enum OCI_ATTR_ENV_UTF16 = 209; /* is env in utf16 mode? */
enum OCI_ATTR_RESERVED_9 = 210; /* reserved */
enum OCI_ATTR_RESERVED_10 = 211; /* reserved */

/* For values 212 and 213, see DirPathAPI attribute section in this file */

enum OCI_ATTR_RESERVED_12 = 214; /* reserved */
enum OCI_ATTR_RESERVED_13 = 215; /* reserved */
enum OCI_ATTR_IS_EXTERNAL = 216; /* whether table is external */

/* -------------------------- Statement Handle Attributes ------------------ */

enum OCI_ATTR_RESERVED_15 = 217; /* reserved */
enum OCI_ATTR_STMT_IS_RETURNING = 218; /* stmt has returning clause */
enum OCI_ATTR_RESERVED_16 = 219; /* reserved */
enum OCI_ATTR_RESERVED_17 = 220; /* reserved */
enum OCI_ATTR_RESERVED_18 = 221; /* reserved */

/* --------------------------- session attributes ---------------------------*/
enum OCI_ATTR_RESERVED_19 = 222; /* reserved */
enum OCI_ATTR_RESERVED_20 = 223; /* reserved */
enum OCI_ATTR_CURRENT_SCHEMA = 224; /* Current Schema */
enum OCI_ATTR_RESERVED_21 = 415; /* reserved */

/* ------------------------- notification subscription ----------------------*/
enum OCI_ATTR_SUBSCR_QOSFLAGS = 225; /* QOS flags */
enum OCI_ATTR_SUBSCR_PAYLOADCBK = 226; /* Payload callback */
enum OCI_ATTR_SUBSCR_TIMEOUT = 227; /* Timeout */
enum OCI_ATTR_SUBSCR_NAMESPACE_CTX = 228; /* Namespace context */
enum OCI_ATTR_SUBSCR_CQ_QOSFLAGS = 229;
/* change notification (CQ) specific QOS flags */
enum OCI_ATTR_SUBSCR_CQ_REGID = 230;
/* change notification registration id */
enum OCI_ATTR_SUBSCR_NTFN_GROUPING_CLASS = 231; /* ntfn grouping class */
enum OCI_ATTR_SUBSCR_NTFN_GROUPING_VALUE = 232; /* ntfn grouping value */
enum OCI_ATTR_SUBSCR_NTFN_GROUPING_TYPE = 233; /* ntfn grouping type */
enum OCI_ATTR_SUBSCR_NTFN_GROUPING_START_TIME = 234; /* ntfn grp start time */
enum OCI_ATTR_SUBSCR_NTFN_GROUPING_REPEAT_COUNT = 235; /* ntfn grp rep count */
enum OCI_ATTR_AQ_NTFN_GROUPING_MSGID_ARRAY = 236; /* aq grp msgid array */
enum OCI_ATTR_AQ_NTFN_GROUPING_COUNT = 237; /* ntfns recd in grp */

/* ----------------------- row callback attributes ------------------------- */
enum OCI_ATTR_BIND_ROWCBK = 301; /* bind row callback */
enum OCI_ATTR_BIND_ROWCTX = 302; /* ctx for bind row callback */
enum OCI_ATTR_SKIP_BUFFER = 303; /* skip buffer in array ops */

/* ----------------------- XStream API attributes -------------------------- */
enum OCI_ATTR_XSTREAM_ACK_INTERVAL = 350; /* XStream ack interval */
enum OCI_ATTR_XSTREAM_IDLE_TIMEOUT = 351; /* XStream idle timeout */

/*-----  Db Change Notification (CQ) statement handle attributes------------ */
enum OCI_ATTR_CQ_QUERYID = 304;
/* ------------- DB Change Notification reg handle attributes ---------------*/
enum OCI_ATTR_CHNF_TABLENAMES = 401; /* out: array of table names   */
enum OCI_ATTR_CHNF_ROWIDS = 402; /* in: rowids needed */
enum OCI_ATTR_CHNF_OPERATIONS = 403;
/* in: notification operation filter*/
enum OCI_ATTR_CHNF_CHANGELAG = 404;
/* txn lag between notifications  */

/* DB Change: Notification Descriptor attributes -----------------------*/
enum OCI_ATTR_CHDES_DBNAME = 405; /* source database    */
enum OCI_ATTR_CHDES_NFYTYPE = 406; /* notification type flags */
enum OCI_ATTR_CHDES_XID = 407; /* XID  of the transaction */
enum OCI_ATTR_CHDES_TABLE_CHANGES = 408; /* array of table chg descriptors*/

enum OCI_ATTR_CHDES_TABLE_NAME = 409; /* table name */
enum OCI_ATTR_CHDES_TABLE_OPFLAGS = 410; /* table operation flags */
enum OCI_ATTR_CHDES_TABLE_ROW_CHANGES = 411; /* array of changed rows   */
enum OCI_ATTR_CHDES_ROW_ROWID = 412; /* rowid of changed row    */
enum OCI_ATTR_CHDES_ROW_OPFLAGS = 413; /* row operation flags     */

/* Statement handle attribute for db change notification */
enum OCI_ATTR_CHNF_REGHANDLE = 414; /* IN: subscription handle  */
enum OCI_ATTR_NETWORK_FILE_DESC = 415; /* network file descriptor */

/* client name for single session proxy */
enum OCI_ATTR_PROXY_CLIENT = 416;

/* 415 is already taken - see OCI_ATTR_RESERVED_21 */

/* TDE attributes on the Table */
enum OCI_ATTR_TABLE_ENC = 417; /* does table have any encrypt columns */
enum OCI_ATTR_TABLE_ENC_ALG = 418; /* Table encryption Algorithm */
enum OCI_ATTR_TABLE_ENC_ALG_ID = 419; /* Internal Id of encryption Algorithm*/

/* -------- Attributes related to Statement cache callback ----------------- */
enum OCI_ATTR_STMTCACHE_CBKCTX = 420; /* opaque context on stmt */
enum OCI_ATTR_STMTCACHE_CBK = 421; /* callback fn for stmtcache */

/*---------------- Query change descriptor attributes -----------------------*/
enum OCI_ATTR_CQDES_OPERATION = 422;
enum OCI_ATTR_CQDES_TABLE_CHANGES = 423;
enum OCI_ATTR_CQDES_QUERYID = 424;

enum OCI_ATTR_CHDES_QUERIES = 425; /* Top level change desc array of queries */

/* Please use from 143 */

/* -------- Internal statement attributes ------- */
enum OCI_ATTR_RESERVED_26 = 422;

/* 424 is used by OCI_ATTR_DRIVER_NAME */
/* --------- Attributes added to support server side session pool ---------- */
enum OCI_ATTR_CONNECTION_CLASS = 425;
enum OCI_ATTR_PURITY = 426;

enum OCI_ATTR_PURITY_DEFAULT = 0x00;
enum OCI_ATTR_PURITY_NEW = 0x01;
enum OCI_ATTR_PURITY_SELF = 0x02;

/* -------- Attributes for Times Ten --------------------------*/
enum OCI_ATTR_RESERVED_28 = 426; /* reserved */
enum OCI_ATTR_RESERVED_29 = 427; /* reserved */
enum OCI_ATTR_RESERVED_30 = 428; /* reserved */
enum OCI_ATTR_RESERVED_31 = 429; /* reserved */
enum OCI_ATTR_RESERVED_32 = 430; /* reserved */
enum OCI_ATTR_RESERVED_41 = 454; /* reserved */

/* ----------- Reserve internal attributes for workload replay  ------------ */
enum OCI_ATTR_RESERVED_33 = 433;
enum OCI_ATTR_RESERVED_34 = 434;

/* statement attribute */
enum OCI_ATTR_RESERVED_36 = 444;

/* -------- Attributes for Network Session Time Out--------------------------*/
enum OCI_ATTR_SEND_TIMEOUT = 435; /* NS send timeout */
enum OCI_ATTR_RECEIVE_TIMEOUT = 436; /* NS receive timeout */

/*--------- Attributes related to LOB prefetch------------------------------ */
enum OCI_ATTR_DEFAULT_LOBPREFETCH_SIZE = 438; /* default prefetch size */
enum OCI_ATTR_LOBPREFETCH_SIZE = 439; /* prefetch size */
enum OCI_ATTR_LOBPREFETCH_LENGTH = 440; /* prefetch length & chunk */

/*--------- Attributes related to LOB Deduplicate Regions ------------------ */
enum OCI_ATTR_LOB_REGION_PRIMARY = 442; /* Primary LOB Locator */
enum OCI_ATTR_LOB_REGION_PRIMOFF = 443; /* Offset into Primary LOB */
enum OCI_ATTR_LOB_REGION_OFFSET = 445; /* Region Offset */
enum OCI_ATTR_LOB_REGION_LENGTH = 446; /* Region Length Bytes/Chars */
enum OCI_ATTR_LOB_REGION_MIME = 447; /* Region mime type */

/*--------------------Attribute to fetch ROWID ------------------------------*/
enum OCI_ATTR_FETCH_ROWID = 448;

/* server attribute */
enum OCI_ATTR_RESERVED_37 = 449;

/*------------------- Client Internal Attributes -----------------------*/
enum OCI_ATTR_RESERVED_38 = 450;
enum OCI_ATTR_RESERVED_39 = 451;

/* --------------- ip address attribute in environment handle -------------- */
enum OCI_ATTR_SUBSCR_IPADDR = 452; /* ip address to listen on  */

/* server attribute */
enum OCI_ATTR_RESERVED_40 = 453;

/* DB Change: Event types ---------------*/
enum OCI_EVENT_NONE = 0x0; /* None */
enum OCI_EVENT_STARTUP = 0x1; /* Startup database */
enum OCI_EVENT_SHUTDOWN = 0x2; /* Shutdown database */
enum OCI_EVENT_SHUTDOWN_ANY = 0x3; /* Startup instance */
enum OCI_EVENT_DROP_DB = 0x4; /* Drop database    */
enum OCI_EVENT_DEREG = 0x5; /* Subscription deregistered */
enum OCI_EVENT_OBJCHANGE = 0x6; /* Object change notification */
enum OCI_EVENT_QUERYCHANGE = 0x7; /* query result change */

/* DB Change: Operation types -----------*/
enum OCI_OPCODE_ALLROWS = 0x1; /* all rows invalidated  */
enum OCI_OPCODE_ALLOPS = 0x0; /* interested in all operations */
enum OCI_OPCODE_INSERT = 0x2; /*  INSERT */
enum OCI_OPCODE_UPDATE = 0x4; /*  UPDATE */
enum OCI_OPCODE_DELETE = 0x8; /* DELETE */
enum OCI_OPCODE_ALTER = 0x10; /* ALTER */
enum OCI_OPCODE_DROP = 0x20; /* DROP TABLE */
enum OCI_OPCODE_UNKNOWN = 0x40; /* GENERIC/ UNKNOWN*/

/* -------- client side character and national character set ids ----------- */
enum OCI_ATTR_ENV_CHARSET_ID = OCI_ATTR_CHARSET_ID; /* charset id in env */
enum OCI_ATTR_ENV_NCHARSET_ID = OCI_ATTR_NCHARSET_ID; /* ncharset id in env */

/* ----------------------- ha event callback attributes -------------------- */
enum OCI_ATTR_EVTCBK = 304; /* ha callback */
enum OCI_ATTR_EVTCTX = 305; /* ctx for ha callback */

/* ------------------ User memory attributes (all handles) ----------------- */
enum OCI_ATTR_USER_MEMORY = 306; /* pointer to user memory */

/* ------- unauthorised access and user action auditing banners ------------ */
enum OCI_ATTR_ACCESS_BANNER = 307; /* access banner */
enum OCI_ATTR_AUDIT_BANNER = 308; /* audit banner */

/* ----------------- port no attribute in environment  handle  ------------- */
enum OCI_ATTR_SUBSCR_PORTNO = 390; /* port no to listen        */

enum OCI_ATTR_RESERVED_35 = 437;

/*------------- Supported Values for protocol for recepient -----------------*/
enum OCI_SUBSCR_PROTO_OCI = 0; /* oci */
enum OCI_SUBSCR_PROTO_MAIL = 1; /* mail */
enum OCI_SUBSCR_PROTO_SERVER = 2; /* server */
enum OCI_SUBSCR_PROTO_HTTP = 3; /* http */
enum OCI_SUBSCR_PROTO_MAX = 4; /* max current protocols */

/*------------- Supported Values for presentation for recepient -------------*/
enum OCI_SUBSCR_PRES_DEFAULT = 0; /* default */
enum OCI_SUBSCR_PRES_XML = 1; /* xml */
enum OCI_SUBSCR_PRES_MAX = 2; /* max current presentations */

/*------------- Supported QOS values for notification registrations ---------*/
enum OCI_SUBSCR_QOS_RELIABLE = 0x01; /* reliable */
enum OCI_SUBSCR_QOS_PAYLOAD = 0x02; /* payload delivery */
enum OCI_SUBSCR_QOS_REPLICATE = 0x04; /* replicate to director */
enum OCI_SUBSCR_QOS_SECURE = 0x08; /* secure payload delivery */
enum OCI_SUBSCR_QOS_PURGE_ON_NTFN = 0x10; /* purge on first ntfn */
enum OCI_SUBSCR_QOS_MULTICBK = 0x20; /* multi instance callback */
/* 0x40 is used for a internal flag */
enum OCI_SUBSCR_QOS_HAREG = 0x80; /* HA reg */

/* ----QOS flags specific to change notification/ continuous queries CQ -----*/
enum OCI_SUBSCR_CQ_QOS_QUERY = 0x01; /* query level notification */
enum OCI_SUBSCR_CQ_QOS_BEST_EFFORT = 0x02; /* best effort notification */
enum OCI_SUBSCR_CQ_QOS_CLQRYCACHE = 0x04; /* client query caching */

/*------------- Supported Values for notification grouping class ------------*/
enum OCI_SUBSCR_NTFN_GROUPING_CLASS_TIME = 1; /* time */

/*------------- Supported Values for notification grouping type -------------*/
enum OCI_SUBSCR_NTFN_GROUPING_TYPE_SUMMARY = 1; /* summary */
enum OCI_SUBSCR_NTFN_GROUPING_TYPE_LAST = 2; /* last */

/* ----- Temporary attribute value for UCS2/UTF16 character set ID -------- */
enum OCI_UCS2ID = 1000; /* UCS2 charset ID */
enum OCI_UTF16ID = 1000; /* UTF16 charset ID */

/*============================== End OCI Attribute Types ====================*/

/*---------------- Server Handle Attribute Values ---------------------------*/

/* OCI_ATTR_SERVER_STATUS */
enum OCI_SERVER_NOT_CONNECTED = 0x0;
enum OCI_SERVER_NORMAL = 0x1;

/*---------------------------------------------------------------------------*/

/*------------------------- Supported Namespaces  ---------------------------*/
enum OCI_SUBSCR_NAMESPACE_ANONYMOUS = 0; /* Anonymous Namespace */
enum OCI_SUBSCR_NAMESPACE_AQ = 1; /* Advanced Queues */
enum OCI_SUBSCR_NAMESPACE_DBCHANGE = 2; /* change notification */
enum OCI_SUBSCR_NAMESPACE_MAX = 3; /* Max Name Space Number */

/*-------------------------Credential Types----------------------------------*/
enum OCI_CRED_RDBMS = 1; /* database username/password */
enum OCI_CRED_EXT = 2; /* externally provided credentials */
enum OCI_CRED_PROXY = 3; /* proxy authentication */
enum OCI_CRED_RESERVED_1 = 4; /* reserved */
enum OCI_CRED_RESERVED_2 = 5; /* reserved */
/*---------------------------------------------------------------------------*/

/*------------------------Error Return Values--------------------------------*/
enum OCI_SUCCESS = 0; /* maps to SQL_SUCCESS of SAG CLI */
enum OCI_SUCCESS_WITH_INFO = 1; /* maps to SQL_SUCCESS_WITH_INFO */
enum OCI_RESERVED_FOR_INT_USE = 200; /* reserved */
enum OCI_NO_DATA = 100; /* maps to SQL_NO_DATA */
enum OCI_ERROR = -1; /* maps to SQL_ERROR */
enum OCI_INVALID_HANDLE = -2; /* maps to SQL_INVALID_HANDLE */
enum OCI_NEED_DATA = 99; /* maps to SQL_NEED_DATA */
enum OCI_STILL_EXECUTING = -3123; /* OCI would block error */
/*---------------------------------------------------------------------------*/

/*--------------------- User Callback Return Values -------------------------*/
enum OCI_CONTINUE = -24200; /* Continue with the body of the OCI function */
enum OCI_ROWCBK_DONE = -24201; /* done with user row callback */
/*---------------------------------------------------------------------------*/

/*------------------DateTime and Interval check Error codes------------------*/

/* DateTime Error Codes used by OCIDateTimeCheck() */
enum OCI_DT_INVALID_DAY = 0x1; /* Bad day */
enum OCI_DT_DAY_BELOW_VALID = 0x2; /* Bad DAy Low/high bit (1=low)*/
enum OCI_DT_INVALID_MONTH = 0x4; /*  Bad MOnth */
enum OCI_DT_MONTH_BELOW_VALID = 0x8; /* Bad MOnth Low/high bit (1=low) */
enum OCI_DT_INVALID_YEAR = 0x10; /* Bad YeaR */
enum OCI_DT_YEAR_BELOW_VALID = 0x20; /*  Bad YeaR Low/high bit (1=low) */
enum OCI_DT_INVALID_HOUR = 0x40; /*  Bad HouR */
enum OCI_DT_HOUR_BELOW_VALID = 0x80; /* Bad HouR Low/high bit (1=low) */
enum OCI_DT_INVALID_MINUTE = 0x100; /* Bad MiNute */
enum OCI_DT_MINUTE_BELOW_VALID = 0x200; /*Bad MiNute Low/high bit (1=low) */
enum OCI_DT_INVALID_SECOND = 0x400; /*  Bad SeCond */
enum OCI_DT_SECOND_BELOW_VALID = 0x800; /*bad second Low/high bit (1=low)*/
enum OCI_DT_DAY_MISSING_FROM_1582 = 0x1000;
/*  Day is one of those "missing" from 1582 */
enum OCI_DT_YEAR_ZERO = 0x2000; /* Year may not equal zero */
enum OCI_DT_INVALID_TIMEZONE = 0x4000; /*  Bad Timezone */
enum OCI_DT_INVALID_FORMAT = 0x8000; /* Bad date format input */

/* Interval Error Codes used by OCIInterCheck() */
enum OCI_INTER_INVALID_DAY = 0x1; /* Bad day */
enum OCI_INTER_DAY_BELOW_VALID = 0x2; /* Bad DAy Low/high bit (1=low) */
enum OCI_INTER_INVALID_MONTH = 0x4; /* Bad MOnth */
enum OCI_INTER_MONTH_BELOW_VALID = 0x8; /*Bad MOnth Low/high bit (1=low) */
enum OCI_INTER_INVALID_YEAR = 0x10; /* Bad YeaR */
enum OCI_INTER_YEAR_BELOW_VALID = 0x20; /*Bad YeaR Low/high bit (1=low) */
enum OCI_INTER_INVALID_HOUR = 0x40; /* Bad HouR */
enum OCI_INTER_HOUR_BELOW_VALID = 0x80; /*Bad HouR Low/high bit (1=low) */
enum OCI_INTER_INVALID_MINUTE = 0x100; /* Bad MiNute */
enum OCI_INTER_MINUTE_BELOW_VALID = 0x200;
/*Bad MiNute Low/high bit(1=low) */
enum OCI_INTER_INVALID_SECOND = 0x400; /* Bad SeCond */
enum OCI_INTER_SECOND_BELOW_VALID = 0x800;
/*bad second Low/high bit(1=low) */
enum OCI_INTER_INVALID_FRACSEC = 0x1000; /* Bad Fractional second */
enum OCI_INTER_FRACSEC_BELOW_VALID = 0x2000;
/* Bad fractional second Low/High */

/*------------------------Parsing Syntax Types-------------------------------*/
enum OCI_V7_SYNTAX = 2; /* V815 language - for backwards compatibility */
enum OCI_V8_SYNTAX = 3; /* V815 language - for backwards compatibility */
enum OCI_NTV_SYNTAX = 1; /* Use what so ever is the native lang of server */
/* these values must match the values defined in kpul.h */
/*---------------------------------------------------------------------------*/

/*------------------------(Scrollable Cursor) Fetch Options-------------------
 * For non-scrollable cursor, the only valid (and default) orientation is
 * OCI_FETCH_NEXT
 */
enum OCI_FETCH_CURRENT = 0x00000001; /* refetching current position  */
enum OCI_FETCH_NEXT = 0x00000002; /* next row */
enum OCI_FETCH_FIRST = 0x00000004; /* first row of the result set */
enum OCI_FETCH_LAST = 0x00000008; /* the last row of the result set */
enum OCI_FETCH_PRIOR = 0x00000010; /* previous row relative to current */
enum OCI_FETCH_ABSOLUTE = 0x00000020; /* absolute offset from first */
enum OCI_FETCH_RELATIVE = 0x00000040; /* offset relative to current */
enum OCI_FETCH_RESERVED_1 = 0x00000080; /* reserved */
enum OCI_FETCH_RESERVED_2 = 0x00000100; /* reserved */
enum OCI_FETCH_RESERVED_3 = 0x00000200; /* reserved */
enum OCI_FETCH_RESERVED_4 = 0x00000400; /* reserved */
enum OCI_FETCH_RESERVED_5 = 0x00000800; /* reserved */
enum OCI_FETCH_RESERVED_6 = 0x00001000; /* reserved */

/*---------------------------------------------------------------------------*/

/*------------------------Bind and Define Options----------------------------*/
enum OCI_SB2_IND_PTR = 0x00000001; /* unused */
enum OCI_DATA_AT_EXEC = 0x00000002; /* data at execute time */
enum OCI_DYNAMIC_FETCH = 0x00000002; /* fetch dynamically */
enum OCI_PIECEWISE = 0x00000004; /* piecewise DMLs or fetch */
enum OCI_DEFINE_RESERVED_1 = 0x00000008; /* reserved */
enum OCI_BIND_RESERVED_2 = 0x00000010; /* reserved */
enum OCI_DEFINE_RESERVED_2 = 0x00000020; /* reserved */
enum OCI_BIND_SOFT = 0x00000040; /* soft bind or define */
enum OCI_DEFINE_SOFT = 0x00000080; /* soft bind or define */
enum OCI_BIND_RESERVED_3 = 0x00000100; /* reserved */
enum OCI_IOV = 0x00000200; /* For scatter gather bind/define */
/*---------------------------------------------------------------------------*/

/*-----------------------------  Various Modes ------------------------------*/
enum OCI_DEFAULT = 0x00000000;
/* the default value for parameters and attributes */
/*-------------OCIInitialize Modes / OCICreateEnvironment Modes -------------*/
enum OCI_THREADED = 0x00000001; /* appl. in threaded environment */
enum OCI_OBJECT = 0x00000002; /* application in object environment */
enum OCI_EVENTS = 0x00000004; /* application is enabled for events */
enum OCI_RESERVED1 = 0x00000008; /* reserved */
enum OCI_SHARED = 0x00000010; /* the application is in shared mode */
enum OCI_RESERVED2 = 0x00000020; /* reserved */
/* The following *TWO* are only valid for OCICreateEnvironment call */
enum OCI_NO_UCB = 0x00000040; /* No user callback called during ini */
enum OCI_NO_MUTEX = 0x00000080; /* the environment handle will not be */
/*  protected by a mutex internally */
enum OCI_SHARED_EXT = 0x00000100; /* Used for shared forms */
/************************** 0x00000200 free **********************************/
enum OCI_ALWAYS_BLOCKING = 0x00000400; /* all connections always blocking */
/************************** 0x00000800 free **********************************/
enum OCI_USE_LDAP = 0x00001000; /* allow  LDAP connections */
enum OCI_REG_LDAPONLY = 0x00002000; /* only register to LDAP */
enum OCI_UTF16 = 0x00004000; /* mode for all UTF16 metadata */
enum OCI_AFC_PAD_ON = 0x00008000;
/* turn on AFC blank padding when rlenp present */
enum OCI_ENVCR_RESERVED3 = 0x00010000; /* reserved */
enum OCI_NEW_LENGTH_SEMANTICS = 0x00020000; /* adopt new length semantics */
/* the new length semantics, always bytes, is used by OCIEnvNlsCreate */
enum OCI_NO_MUTEX_STMT = 0x00040000; /* Do not mutex stmt handle */
enum OCI_MUTEX_ENV_ONLY = 0x00080000; /* Mutex only the environment handle */
enum OCI_SUPPRESS_NLS_VALIDATION = 0x00100000; /* suppress nls validation */
/* nls validation suppression is on by default;
   use OCI_ENABLE_NLS_VALIDATION to disable it */
enum OCI_MUTEX_TRY = 0x00200000; /* try and acquire mutex */
enum OCI_NCHAR_LITERAL_REPLACE_ON = 0x00400000; /* nchar literal replace on */
enum OCI_NCHAR_LITERAL_REPLACE_OFF = 0x00800000; /* nchar literal replace off*/
enum OCI_ENABLE_NLS_VALIDATION = 0x01000000; /* enable nls validation */
enum OCI_ENVCR_RESERVED4 = 0x02000000; /* reserved */

/*---------------------------------------------------------------------------*/
/*------------------------OCIConnectionpoolCreate Modes----------------------*/

enum OCI_CPOOL_REINITIALIZE = 0x111;

/*---------------------------------------------------------------------------*/
/*--------------------------------- OCILogon2 Modes -------------------------*/

enum OCI_LOGON2_SPOOL = 0x0001; /* Use session pool */
enum OCI_LOGON2_CPOOL = OCI_CPOOL; /* Use connection pool */
enum OCI_LOGON2_STMTCACHE = 0x0004; /* Use Stmt Caching */
enum OCI_LOGON2_PROXY = 0x0008; /* Proxy authentiaction */

/*---------------------------------------------------------------------------*/
/*------------------------- OCISessionPoolCreate Modes ----------------------*/

enum OCI_SPC_REINITIALIZE = 0x0001; /* Reinitialize the session pool */
enum OCI_SPC_HOMOGENEOUS = 0x0002; /* Session pool is homogeneneous */
enum OCI_SPC_STMTCACHE = 0x0004; /* Session pool has stmt cache */
enum OCI_SPC_NO_RLB = 0x0008; /* Do not enable Runtime load balancing. */

/*---------------------------------------------------------------------------*/
/*--------------------------- OCISessionGet Modes ---------------------------*/

enum OCI_SESSGET_SPOOL = 0x0001; /* SessionGet called in SPOOL mode */
enum OCI_SESSGET_CPOOL = OCI_CPOOL; /* SessionGet called in CPOOL mode */
enum OCI_SESSGET_STMTCACHE = 0x0004; /* Use statement cache */
enum OCI_SESSGET_CREDPROXY = 0x0008; /* SessionGet called in proxy mode */
enum OCI_SESSGET_CREDEXT = 0x0010;
enum OCI_SESSGET_SPOOL_MATCHANY = 0x0020;
enum OCI_SESSGET_PURITY_NEW = 0x0040;
enum OCI_SESSGET_PURITY_SELF = 0x0080;
enum OCI_SESSGET_SYSDBA = 0x0100; /* SessionGet with SYSDBA privileges */

/*---------------------------------------------------------------------------*/
/*------------------------ATTR Values for Session Pool-----------------------*/
/* Attribute values for OCI_ATTR_SPOOL_GETMODE */
enum OCI_SPOOL_ATTRVAL_WAIT = 0; /* block till you get a session */
enum OCI_SPOOL_ATTRVAL_NOWAIT = 1; /* error out if no session avaliable */
enum OCI_SPOOL_ATTRVAL_FORCEGET = 2; /* get session even if max is exceeded */

/*---------------------------------------------------------------------------*/
/*--------------------------- OCISessionRelease Modes -----------------------*/

enum OCI_SESSRLS_DROPSESS = 0x0001; /* Drop the Session */
enum OCI_SESSRLS_RETAG = 0x0002; /* Retag the session */

/*---------------------------------------------------------------------------*/
/*----------------------- OCISessionPoolDestroy Modes -----------------------*/

enum OCI_SPD_FORCE = 0x0001; /* Force the sessions to terminate.
   Even if there are some busy
   sessions close them */

/*---------------------------------------------------------------------------*/
/*----------------------------- Statement States ----------------------------*/

enum OCI_STMT_STATE_INITIALIZED = 0x0001;
enum OCI_STMT_STATE_EXECUTED = 0x0002;
enum OCI_STMT_STATE_END_OF_FETCH = 0x0003;

/*---------------------------------------------------------------------------*/

/*----------------------------- OCIMemStats Modes ---------------------------*/
enum OCI_MEM_INIT = 0x01;
enum OCI_MEM_CLN = 0x02;
enum OCI_MEM_FLUSH = 0x04;
enum OCI_DUMP_HEAP = 0x80;

enum OCI_CLIENT_STATS = 0x10;
enum OCI_SERVER_STATS = 0x20;

/*----------------------------- OCIEnvInit Modes ----------------------------*/
/* NOTE: NO NEW MODES SHOULD BE ADDED HERE BECAUSE THE RECOMMENDED METHOD
 * IS TO USE THE NEW OCICreateEnvironment MODES.
 */
enum OCI_ENV_NO_UCB = 0x01; /* A user callback will not be called in
   OCIEnvInit() */
enum OCI_ENV_NO_MUTEX = 0x08; /* the environment handle will not be protected
   by a mutex internally */

/*---------------------------------------------------------------------------*/

/*------------------------ Prepare Modes ------------------------------------*/
enum OCI_NO_SHARING = 0x01; /* turn off statement handle sharing */
enum OCI_PREP_RESERVED_1 = 0x02; /* reserved */
enum OCI_PREP_AFC_PAD_ON = 0x04; /* turn on blank padding for AFC */
enum OCI_PREP_AFC_PAD_OFF = 0x08; /* turn off blank padding for AFC */
/*---------------------------------------------------------------------------*/

/*---------------------------------------------------------------------------*/

/*----------------------- Execution Modes -----------------------------------*/
enum OCI_BATCH_MODE = 0x00000001; /* batch the oci stmt for exec */
enum OCI_EXACT_FETCH = 0x00000002; /* fetch exact rows specified */
/* #define                         0x00000004                      available */
enum OCI_STMT_SCROLLABLE_READONLY = 0x00000008; /* if result set is scrollable */
enum OCI_DESCRIBE_ONLY = 0x00000010; /* only describe the statement */
enum OCI_COMMIT_ON_SUCCESS = 0x00000020; /* commit, if successful exec */
enum OCI_NON_BLOCKING = 0x00000040; /* non-blocking */
enum OCI_BATCH_ERRORS = 0x00000080; /* batch errors in array dmls */
enum OCI_PARSE_ONLY = 0x00000100; /* only parse the statement */
enum OCI_EXACT_FETCH_RESERVED_1 = 0x00000200; /* reserved */
enum OCI_SHOW_DML_WARNINGS = 0x00000400;
/* return OCI_SUCCESS_WITH_INFO for delete/update w/no where clause */
enum OCI_EXEC_RESERVED_2 = 0x00000800; /* reserved */
enum OCI_DESC_RESERVED_1 = 0x00001000; /* reserved */
enum OCI_EXEC_RESERVED_3 = 0x00002000; /* reserved */
enum OCI_EXEC_RESERVED_4 = 0x00004000; /* reserved */
enum OCI_EXEC_RESERVED_5 = 0x00008000; /* reserved */
enum OCI_EXEC_RESERVED_6 = 0x00010000; /* reserved */
enum OCI_RESULT_CACHE = 0x00020000; /* hint to use query caching */
enum OCI_NO_RESULT_CACHE = 0x00040000; /*hint to bypass query caching*/
enum OCI_EXEC_RESERVED_7 = 0x00080000; /* reserved */

/*---------------------------------------------------------------------------*/

/*------------------------Authentication Modes-------------------------------*/
enum OCI_MIGRATE = 0x00000001; /* migratable auth context */
enum OCI_SYSDBA = 0x00000002; /* for SYSDBA authorization */
enum OCI_SYSOPER = 0x00000004; /* for SYSOPER authorization */
enum OCI_PRELIM_AUTH = 0x00000008; /* for preliminary authorization */
enum OCIP_ICACHE = 0x00000010; /* Private OCI cache mode */
enum OCI_AUTH_RESERVED_1 = 0x00000020; /* reserved */
enum OCI_STMT_CACHE = 0x00000040; /* enable OCI Stmt Caching */
enum OCI_STATELESS_CALL = 0x00000080; /* stateless at call boundary */
enum OCI_STATELESS_TXN = 0x00000100; /* stateless at txn boundary */
enum OCI_STATELESS_APP = 0x00000200; /* stateless at user-specified pts */
enum OCI_AUTH_RESERVED_2 = 0x00000400; /* reserved */
enum OCI_AUTH_RESERVED_3 = 0x00000800; /* reserved */
enum OCI_AUTH_RESERVED_4 = 0x00001000; /* reserved */
enum OCI_AUTH_RESERVED_5 = 0x00002000; /* reserved */
enum OCI_SYSASM = 0x00008000; /* for SYSASM authorization */
enum OCI_AUTH_RESERVED_6 = 0x00010000; /* reserved */

/*---------------------------------------------------------------------------*/

/*------------------------Session End Modes----------------------------------*/
enum OCI_SESSEND_RESERVED_1 = 0x0001; /* reserved */
enum OCI_SESSEND_RESERVED_2 = 0x0002; /* reserved */
/*---------------------------------------------------------------------------*/

/*------------------------Attach Modes---------------------------------------*/

/* The following attach modes are the same as the UPI modes defined in
 * UPIDEF.H.  Do not use these values externally.
 */

enum OCI_FASTPATH = 0x0010; /* Attach in fast path mode */
enum OCI_ATCH_RESERVED_1 = 0x0020; /* reserved */
enum OCI_ATCH_RESERVED_2 = 0x0080; /* reserved */
enum OCI_ATCH_RESERVED_3 = 0x0100; /* reserved */
enum OCI_CPOOL = 0x0200; /* Attach using server handle from pool */
enum OCI_ATCH_RESERVED_4 = 0x0400; /* reserved */
enum OCI_ATCH_RESERVED_5 = 0x2000; /* reserved */
enum OCI_ATCH_ENABLE_BEQ = 0x4000; /* Allow bequeath connect strings */
enum OCI_ATCH_RESERVED_6 = 0x8000; /* reserved */
enum OCI_ATCH_RESERVED_7 = 0x10000; /* reserved */
enum OCI_ATCH_RESERVED_8 = 0x20000; /* reserved */

enum OCI_SRVATCH_RESERVED5 = 0x01000000; /* reserved */
enum OCI_SRVATCH_RESERVED6 = 0x02000000; /* reserved */

/*---------------------OCIStmtPrepare2 Modes---------------------------------*/
enum OCI_PREP2_CACHE_SEARCHONLY = 0x0010; /* ONly Search */
enum OCI_PREP2_GET_PLSQL_WARNINGS = 0x0020; /* Get PL/SQL warnings  */
enum OCI_PREP2_RESERVED_1 = 0x0040; /* reserved */

/*---------------------OCIStmtRelease Modes----------------------------------*/
enum OCI_STRLS_CACHE_DELETE = 0x0010; /* Delete from Cache */

/*---------------------OCIHanlde Mgmt Misc Modes-----------------------------*/
enum OCI_STM_RESERVED4 = 0x00100000; /* reserved */

/*-----------------------------End Various Modes ----------------------------*/

/*------------------------Piece Information----------------------------------*/
enum OCI_PARAM_IN = 0x01; /* in parameter */
enum OCI_PARAM_OUT = 0x02; /* out parameter */
/*---------------------------------------------------------------------------*/

/*------------------------ Transaction Start Flags --------------------------*/
/* NOTE: OCI_TRANS_JOIN and OCI_TRANS_NOMIGRATE not supported in 8.0.X       */
enum OCI_TRANS_NEW = 0x00000001; /* start a new local or global txn */
enum OCI_TRANS_JOIN = 0x00000002; /* join an existing global txn */
enum OCI_TRANS_RESUME = 0x00000004; /* resume the global txn branch */
enum OCI_TRANS_PROMOTE = 0x00000008; /* promote the local txn to global */
enum OCI_TRANS_STARTMASK = 0x000000ff; /* mask for start operation flags */

enum OCI_TRANS_READONLY = 0x00000100; /* start a readonly txn */
enum OCI_TRANS_READWRITE = 0x00000200; /* start a read-write txn */
enum OCI_TRANS_SERIALIZABLE = 0x00000400; /* start a serializable txn */
enum OCI_TRANS_ISOLMASK = 0x0000ff00; /* mask for start isolation flags */

enum OCI_TRANS_LOOSE = 0x00010000; /* a loosely coupled branch */
enum OCI_TRANS_TIGHT = 0x00020000; /* a tightly coupled branch */
enum OCI_TRANS_TYPEMASK = 0x000f0000; /* mask for branch type flags */

enum OCI_TRANS_NOMIGRATE = 0x00100000; /* non migratable transaction */
enum OCI_TRANS_SEPARABLE = 0x00200000; /* separable transaction (8.1.6+) */
enum OCI_TRANS_OTSRESUME = 0x00400000; /* OTS resuming a transaction */
enum OCI_TRANS_OTHRMASK = 0xfff00000; /* mask for other start flags */

/*---------------------------------------------------------------------------*/

/*------------------------ Transaction End Flags ----------------------------*/
enum OCI_TRANS_TWOPHASE = 0x01000000; /* use two phase commit */
enum OCI_TRANS_WRITEBATCH = 0x00000001; /* force cmt-redo for local txns */
enum OCI_TRANS_WRITEIMMED = 0x00000002; /* no force cmt-redo */
enum OCI_TRANS_WRITEWAIT = 0x00000004; /* no sync cmt-redo */
enum OCI_TRANS_WRITENOWAIT = 0x00000008; /* sync cmt-redo for local txns */
/*---------------------------------------------------------------------------*/

/*------------------------- AQ Constants ------------------------------------
 * NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE
 * The following constants must match the PL/SQL dbms_aq constants
 * NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE NOTE
 */
/* ------------------------- Visibility flags -------------------------------*/
enum OCI_ENQ_IMMEDIATE = 1; /* enqueue is an independent transaction */
enum OCI_ENQ_ON_COMMIT = 2; /* enqueue is part of current transaction */

/* ----------------------- Dequeue mode flags -------------------------------*/
enum OCI_DEQ_BROWSE = 1; /* read message without acquiring a lock */
enum OCI_DEQ_LOCKED = 2; /* read and obtain write lock on message */
enum OCI_DEQ_REMOVE = 3; /* read the message and delete it */
enum OCI_DEQ_REMOVE_NODATA = 4; /* delete message w'o returning payload */
enum OCI_DEQ_GETSIG = 5; /* get signature only */

/* ----------------- Dequeue navigation flags -------------------------------*/
enum OCI_DEQ_FIRST_MSG = 1; /* get first message at head of queue */
enum OCI_DEQ_NEXT_MSG = 3; /* next message that is available */
enum OCI_DEQ_NEXT_TRANSACTION = 2; /* get first message of next txn group */
enum OCI_DEQ_FIRST_MSG_MULTI_GROUP = 4;
/* start from first message and array deq across txn groups */
enum OCI_DEQ_MULT_TRANSACTION = 5; /* array dequeue across txn groups */
enum OCI_DEQ_NEXT_MSG_MULTI_GROUP = OCI_DEQ_MULT_TRANSACTION;
/* array dequeue across txn groups */

/* ----------------- Dequeue Option Reserved flags ------------------------- */
enum OCI_DEQ_RESERVED_1 = 0x000001;

/* --------------------- Message states -------------------------------------*/
enum OCI_MSG_WAITING = 1; /* the message delay has not yet completed */
enum OCI_MSG_READY = 0; /* the message is ready to be processed */
enum OCI_MSG_PROCESSED = 2; /* the message has been processed */
enum OCI_MSG_EXPIRED = 3; /* message has moved to exception queue */

/* --------------------- Sequence deviation ---------------------------------*/
enum OCI_ENQ_BEFORE = 2; /* enqueue message before another message */
enum OCI_ENQ_TOP = 3; /* enqueue message before all messages */

/* ------------------------- Visibility flags -------------------------------*/
enum OCI_DEQ_IMMEDIATE = 1; /* dequeue is an independent transaction */
enum OCI_DEQ_ON_COMMIT = 2; /* dequeue is part of current transaction */

/* ------------------------ Wait --------------------------------------------*/
enum OCI_DEQ_WAIT_FOREVER = -1; /* wait forever if no message available */
enum OCI_NTFN_GROUPING_FOREVER = -1; /* send grouping notifications forever */
enum OCI_DEQ_NO_WAIT = 0; /* do not wait if no message is available */

enum OCI_FLOW_CONTROL_NO_TIMEOUT = -1;
/* streaming enqueue: no timeout for flow control */

/* ------------------------ Delay -------------------------------------------*/
enum OCI_MSG_NO_DELAY = 0; /* message is available immediately */

/* ------------------------- Expiration -------------------------------------*/
enum OCI_MSG_NO_EXPIRATION = -1; /* message will never expire */

enum OCI_MSG_PERSISTENT_OR_BUFFERED = 3;
enum OCI_MSG_BUFFERED = 2;
enum OCI_MSG_PERSISTENT = 1;

/* ----------------------- Reserved/AQE pisdef flags ------------------------*/
/* see aqeflg defines in kwqp.h */
enum OCI_AQ_RESERVED_1 = 0x0002;
enum OCI_AQ_RESERVED_2 = 0x0004;
enum OCI_AQ_RESERVED_3 = 0x0008;
enum OCI_AQ_RESERVED_4 = 0x0010;

enum OCI_AQ_STREAMING_FLAG = 0x02000000;

/* ------------------------------ Replay Info -------------------------------*/
enum OCI_AQ_LAST_ENQUEUED = 0;
enum OCI_AQ_LAST_ACKNOWLEDGED = 1;

/* -------------------------- END AQ Constants ----------------------------- */

/* --------------------END DateTime and Interval Constants ------------------*/

/*-----------------------Object Types----------------------------------------*/
/*-----------Object Types **** Not to be Used **** --------------------------*/
/* Deprecated */
enum OCI_OTYPE_UNK = 0;
enum OCI_OTYPE_TABLE = 1;
enum OCI_OTYPE_VIEW = 2;
enum OCI_OTYPE_SYN = 3;
enum OCI_OTYPE_PROC = 4;
enum OCI_OTYPE_FUNC = 5;
enum OCI_OTYPE_PKG = 6;
enum OCI_OTYPE_STMT = 7;
/*---------------------------------------------------------------------------*/

/*=======================Describe Handle Parameter Attributes ===============*/
/*
   These attributes are orthogonal to the other set of attributes defined
   above.  These attrubutes are to be used only for the describe handle.
*/
/*===========================================================================*/
/* Attributes common to Columns and Stored Procs */
enum OCI_ATTR_DATA_SIZE = 1; /* maximum size of the data */
enum OCI_ATTR_DATA_TYPE = 2; /* the SQL type of the column/argument */
enum OCI_ATTR_DISP_SIZE = 3; /* the display size */
enum OCI_ATTR_NAME = 4; /* the name of the column/argument */
enum OCI_ATTR_PRECISION = 5; /* precision if number type */
enum OCI_ATTR_SCALE = 6; /* scale if number type */
enum OCI_ATTR_IS_NULL = 7; /* is it null ? */
enum OCI_ATTR_TYPE_NAME = 8;
/* name of the named data type or a package name for package private types */
enum OCI_ATTR_SCHEMA_NAME = 9; /* the schema name */
enum OCI_ATTR_SUB_NAME = 10; /* type name if package private type */
enum OCI_ATTR_POSITION = 11;
/* relative position of col/arg in the list of cols/args */
/* complex object retrieval parameter attributes */
enum OCI_ATTR_COMPLEXOBJECTCOMP_TYPE = 50;
enum OCI_ATTR_COMPLEXOBJECTCOMP_TYPE_LEVEL = 51;
enum OCI_ATTR_COMPLEXOBJECT_LEVEL = 52;
enum OCI_ATTR_COMPLEXOBJECT_COLL_OUTOFLINE = 53;

/* Only Columns */
enum OCI_ATTR_DISP_NAME = 100; /* the display name */
enum OCI_ATTR_ENCC_SIZE = 101; /* encrypted data size */
enum OCI_ATTR_COL_ENC = 102; /* column is encrypted ? */
enum OCI_ATTR_COL_ENC_SALT = 103; /* is encrypted column salted ? */

/*Only Stored Procs */
enum OCI_ATTR_OVERLOAD = 210; /* is this position overloaded */
enum OCI_ATTR_LEVEL = 211; /* level for structured types */
enum OCI_ATTR_HAS_DEFAULT = 212; /* has a default value */
enum OCI_ATTR_IOMODE = 213; /* in, out inout */
enum OCI_ATTR_RADIX = 214; /* returns a radix */
enum OCI_ATTR_NUM_ARGS = 215; /* total number of arguments */

/* only named type attributes */
enum OCI_ATTR_TYPECODE = 216; /* object or collection */
enum OCI_ATTR_COLLECTION_TYPECODE = 217; /* varray or nested table */
enum OCI_ATTR_VERSION = 218; /* user assigned version */
enum OCI_ATTR_IS_INCOMPLETE_TYPE = 219; /* is this an incomplete type */
enum OCI_ATTR_IS_SYSTEM_TYPE = 220; /* a system type */
enum OCI_ATTR_IS_PREDEFINED_TYPE = 221; /* a predefined type */
enum OCI_ATTR_IS_TRANSIENT_TYPE = 222; /* a transient type */
enum OCI_ATTR_IS_SYSTEM_GENERATED_TYPE = 223; /* system generated type */
enum OCI_ATTR_HAS_NESTED_TABLE = 224; /* contains nested table attr */
enum OCI_ATTR_HAS_LOB = 225; /* has a lob attribute */
enum OCI_ATTR_HAS_FILE = 226; /* has a file attribute */
enum OCI_ATTR_COLLECTION_ELEMENT = 227; /* has a collection attribute */
enum OCI_ATTR_NUM_TYPE_ATTRS = 228; /* number of attribute types */
enum OCI_ATTR_LIST_TYPE_ATTRS = 229; /* list of type attributes */
enum OCI_ATTR_NUM_TYPE_METHODS = 230; /* number of type methods */
enum OCI_ATTR_LIST_TYPE_METHODS = 231; /* list of type methods */
enum OCI_ATTR_MAP_METHOD = 232; /* map method of type */
enum OCI_ATTR_ORDER_METHOD = 233; /* order method of type */

/* only collection element */
enum OCI_ATTR_NUM_ELEMS = 234; /* number of elements */

/* only type methods */
enum OCI_ATTR_ENCAPSULATION = 235; /* encapsulation level */
enum OCI_ATTR_IS_SELFISH = 236; /* method selfish */
enum OCI_ATTR_IS_VIRTUAL = 237; /* virtual */
enum OCI_ATTR_IS_INLINE = 238; /* inline */
enum OCI_ATTR_IS_CONSTANT = 239; /* constant */
enum OCI_ATTR_HAS_RESULT = 240; /* has result */
enum OCI_ATTR_IS_CONSTRUCTOR = 241; /* constructor */
enum OCI_ATTR_IS_DESTRUCTOR = 242; /* destructor */
enum OCI_ATTR_IS_OPERATOR = 243; /* operator */
enum OCI_ATTR_IS_MAP = 244; /* a map method */
enum OCI_ATTR_IS_ORDER = 245; /* order method */
enum OCI_ATTR_IS_RNDS = 246; /* read no data state method */
enum OCI_ATTR_IS_RNPS = 247; /* read no process state */
enum OCI_ATTR_IS_WNDS = 248; /* write no data state method */
enum OCI_ATTR_IS_WNPS = 249; /* write no process state */

enum OCI_ATTR_DESC_PUBLIC = 250; /* public object */

/* Object Cache Enhancements : attributes for User Constructed Instances     */
enum OCI_ATTR_CACHE_CLIENT_CONTEXT = 251;
enum OCI_ATTR_UCI_CONSTRUCT = 252;
enum OCI_ATTR_UCI_DESTRUCT = 253;
enum OCI_ATTR_UCI_COPY = 254;
enum OCI_ATTR_UCI_PICKLE = 255;
enum OCI_ATTR_UCI_UNPICKLE = 256;
enum OCI_ATTR_UCI_REFRESH = 257;

/* for type inheritance */
enum OCI_ATTR_IS_SUBTYPE = 258;
enum OCI_ATTR_SUPERTYPE_SCHEMA_NAME = 259;
enum OCI_ATTR_SUPERTYPE_NAME = 260;

/* for schemas */
enum OCI_ATTR_LIST_OBJECTS = 261; /* list of objects in schema */

/* for database */
enum OCI_ATTR_NCHARSET_ID = 262; /* char set id */
enum OCI_ATTR_LIST_SCHEMAS = 263; /* list of schemas */
enum OCI_ATTR_MAX_PROC_LEN = 264; /* max procedure length */
enum OCI_ATTR_MAX_COLUMN_LEN = 265; /* max column name length */
enum OCI_ATTR_CURSOR_COMMIT_BEHAVIOR = 266; /* cursor commit behavior */
enum OCI_ATTR_MAX_CATALOG_NAMELEN = 267; /* catalog namelength */
enum OCI_ATTR_CATALOG_LOCATION = 268; /* catalog location */
enum OCI_ATTR_SAVEPOINT_SUPPORT = 269; /* savepoint support */
enum OCI_ATTR_NOWAIT_SUPPORT = 270; /* nowait support */
enum OCI_ATTR_AUTOCOMMIT_DDL = 271; /* autocommit DDL */
enum OCI_ATTR_LOCKING_MODE = 272; /* locking mode */

/* for externally initialized context */
enum OCI_ATTR_APPCTX_SIZE = 273; /* count of context to be init*/
enum OCI_ATTR_APPCTX_LIST = 274; /* count of context to be init*/
enum OCI_ATTR_APPCTX_NAME = 275; /* name  of context to be init*/
enum OCI_ATTR_APPCTX_ATTR = 276; /* attr  of context to be init*/
enum OCI_ATTR_APPCTX_VALUE = 277; /* value of context to be init*/

/* for client id propagation */
enum OCI_ATTR_CLIENT_IDENTIFIER = 278; /* value of client id to set*/

/* for inheritance - part 2 */
enum OCI_ATTR_IS_FINAL_TYPE = 279; /* is final type ? */
enum OCI_ATTR_IS_INSTANTIABLE_TYPE = 280; /* is instantiable type ? */
enum OCI_ATTR_IS_FINAL_METHOD = 281; /* is final method ? */
enum OCI_ATTR_IS_INSTANTIABLE_METHOD = 282; /* is instantiable method ? */
enum OCI_ATTR_IS_OVERRIDING_METHOD = 283; /* is overriding method ? */

enum OCI_ATTR_DESC_SYNBASE = 284; /* Describe the base object */

enum OCI_ATTR_CHAR_USED = 285; /* char length semantics */
enum OCI_ATTR_CHAR_SIZE = 286; /* char length */

/* SQLJ support */
enum OCI_ATTR_IS_JAVA_TYPE = 287; /* is java implemented type ? */

/* N-Tier support */
enum OCI_ATTR_DISTINGUISHED_NAME = 300; /* use DN as user name */
enum OCI_ATTR_KERBEROS_TICKET = 301; /* Kerberos ticket as cred. */

/* for multilanguage debugging */
enum OCI_ATTR_ORA_DEBUG_JDWP = 302; /* ORA_DEBUG_JDWP attribute */

enum OCI_ATTR_EDITION = 288; /* ORA_EDITION */

enum OCI_ATTR_RESERVED_14 = 303; /* reserved */

/*---------------------------End Describe Handle Attributes -----------------*/

/* For values 303 - 307, see DirPathAPI attribute section in this file */

/* ----------------------- Session Pool Attributes ------------------------- */
enum OCI_ATTR_SPOOL_TIMEOUT = 308; /* session timeout */
enum OCI_ATTR_SPOOL_GETMODE = 309; /* session get mode */
enum OCI_ATTR_SPOOL_BUSY_COUNT = 310; /* busy session count */
enum OCI_ATTR_SPOOL_OPEN_COUNT = 311; /* open session count */
enum OCI_ATTR_SPOOL_MIN = 312; /* min session count */
enum OCI_ATTR_SPOOL_MAX = 313; /* max session count */
enum OCI_ATTR_SPOOL_INCR = 314; /* session increment count */
enum OCI_ATTR_SPOOL_STMTCACHESIZE = 208; /*Stmt cache size of pool  */
enum OCI_ATTR_SPOOL_AUTH = 460; /* Auth handle on pool handle*/
/*------------------------------End Session Pool Attributes -----------------*/
/*---------------------------- For XML Types ------------------------------- */
/* For table, view and column */
enum OCI_ATTR_IS_XMLTYPE = 315; /* Is the type an XML type? */
enum OCI_ATTR_XMLSCHEMA_NAME = 316; /* Name of XML Schema */
enum OCI_ATTR_XMLELEMENT_NAME = 317; /* Name of XML Element */
enum OCI_ATTR_XMLSQLTYPSCH_NAME = 318; /* SQL type's schema for XML Ele */
enum OCI_ATTR_XMLSQLTYPE_NAME = 319; /* Name of SQL type for XML Ele */
enum OCI_ATTR_XMLTYPE_STORED_OBJ = 320; /* XML type stored as object? */
enum OCI_ATTR_XMLTYPE_BINARY_XML = 422; /* XML type stored as binary? */

/*---------------------------- For Subtypes ------------------------------- */
/* For type */
enum OCI_ATTR_HAS_SUBTYPES = 321; /* Has subtypes? */
enum OCI_ATTR_NUM_SUBTYPES = 322; /* Number of subtypes */
enum OCI_ATTR_LIST_SUBTYPES = 323; /* List of subtypes */

/* XML flag */
enum OCI_ATTR_XML_HRCHY_ENABLED = 324; /* hierarchy enabled? */

/* Method flag */
enum OCI_ATTR_IS_OVERRIDDEN_METHOD = 325; /* Method is overridden? */

/* For values 326 - 335, see DirPathAPI attribute section in this file */

/*------------- Attributes for 10i Distributed Objects ----------------------*/
enum OCI_ATTR_OBJ_SUBS = 336; /* obj col/tab substitutable */

/* For values 337 - 338, see DirPathAPI attribute section in this file */

/*---------- Attributes for 10i XADFIELD (NLS language, territory -----------*/
enum OCI_ATTR_XADFIELD_RESERVED_1 = 339; /* reserved */
enum OCI_ATTR_XADFIELD_RESERVED_2 = 340; /* reserved */
/*------------- Kerberos Secure Client Identifier ---------------------------*/
enum OCI_ATTR_KERBEROS_CID = 341; /* Kerberos db service ticket*/

/*------------------------ Attributes for Rules objects ---------------------*/
enum OCI_ATTR_CONDITION = 342; /* rule condition */
enum OCI_ATTR_COMMENT = 343; /* comment */
enum OCI_ATTR_VALUE = 344; /* Anydata value */
enum OCI_ATTR_EVAL_CONTEXT_OWNER = 345; /* eval context owner */
enum OCI_ATTR_EVAL_CONTEXT_NAME = 346; /* eval context name */
enum OCI_ATTR_EVALUATION_FUNCTION = 347; /* eval function name */
enum OCI_ATTR_VAR_TYPE = 348; /* variable type */
enum OCI_ATTR_VAR_VALUE_FUNCTION = 349; /* variable value function */
enum OCI_ATTR_VAR_METHOD_FUNCTION = 350; /* variable method function */
enum OCI_ATTR_ACTION_CONTEXT = 351; /* action context */
enum OCI_ATTR_LIST_TABLE_ALIASES = 352; /* list of table aliases */
enum OCI_ATTR_LIST_VARIABLE_TYPES = 353; /* list of variable types */
enum OCI_ATTR_TABLE_NAME = 356; /* table name */

/* For values 357 - 359, see DirPathAPI attribute section in this file */

enum OCI_ATTR_MESSAGE_CSCN = 360; /* message cscn */
enum OCI_ATTR_MESSAGE_DSCN = 361; /* message dscn */

/*--------------------- Audit Session ID ------------------------------------*/
enum OCI_ATTR_AUDIT_SESSION_ID = 362; /* Audit session ID */

/*--------------------- Kerberos TGT Keys -----------------------------------*/
enum OCI_ATTR_KERBEROS_KEY = 363; /* n-tier Kerberos cred key */
enum OCI_ATTR_KERBEROS_CID_KEY = 364; /* SCID Kerberos cred key */

enum OCI_ATTR_TRANSACTION_NO = 365; /* AQ enq txn number */

/*----------------------- Attributes for End To End Tracing -----------------*/
enum OCI_ATTR_MODULE = 366; /* module for tracing */
enum OCI_ATTR_ACTION = 367; /* action for tracing */
enum OCI_ATTR_CLIENT_INFO = 368; /* client info */
enum OCI_ATTR_COLLECT_CALL_TIME = 369; /* collect call time */
enum OCI_ATTR_CALL_TIME = 370; /* extract call time */
enum OCI_ATTR_ECONTEXT_ID = 371; /* execution-id context */
enum OCI_ATTR_ECONTEXT_SEQ = 372; /*execution-id sequence num */

/*------------------------------ Session attributes -------------------------*/
enum OCI_ATTR_SESSION_STATE = 373; /* session state */
enum OCI_SESSION_STATELESS = 1; /* valid states */
enum OCI_SESSION_STATEFUL = 2;

enum OCI_ATTR_SESSION_STATETYPE = 374; /* session state type */
enum OCI_SESSION_STATELESS_DEF = 0; /* valid state types */
enum OCI_SESSION_STATELESS_CAL = 1;
enum OCI_SESSION_STATELESS_TXN = 2;
enum OCI_SESSION_STATELESS_APP = 3;

enum OCI_ATTR_SESSION_STATE_CLEARED = 376; /* session state cleared */
enum OCI_ATTR_SESSION_MIGRATED = 377; /* did session migrate */
enum OCI_ATTR_SESSION_PRESERVE_STATE = 388; /* preserve session state */
enum OCI_ATTR_DRIVER_NAME = 424; /* Driver Name */

/* -------------------------- Admin Handle Attributes ---------------------- */

enum OCI_ATTR_ADMIN_PFILE = 389; /* client-side param file */

/*----------------------- Attributes for End To End Tracing -----------------*/
/* -------------------------- HA Event Handle Attributes ------------------- */

enum OCI_ATTR_HOSTNAME = 390; /* SYS_CONTEXT hostname */
enum OCI_ATTR_DBNAME = 391; /* SYS_CONTEXT dbname */
enum OCI_ATTR_INSTNAME = 392; /* SYS_CONTEXT instance name */
enum OCI_ATTR_SERVICENAME = 393; /* SYS_CONTEXT service name */
enum OCI_ATTR_INSTSTARTTIME = 394; /* v$instance instance start time */
enum OCI_ATTR_HA_TIMESTAMP = 395; /* event time */
enum OCI_ATTR_RESERVED_22 = 396; /* reserved */
enum OCI_ATTR_RESERVED_23 = 397; /* reserved */
enum OCI_ATTR_RESERVED_24 = 398; /* reserved */
enum OCI_ATTR_DBDOMAIN = 399; /* db domain */
enum OCI_ATTR_RESERVED_27 = 425; /* reserved */

enum OCI_ATTR_EVENTTYPE = 400; /* event type */
enum OCI_EVENTTYPE_HA = 0; /* valid value for OCI_ATTR_EVENTTYPE */

enum OCI_ATTR_HA_SOURCE = 401;
/* valid values for OCI_ATTR_HA_SOURCE */
enum OCI_HA_SOURCE_INSTANCE = 0;
enum OCI_HA_SOURCE_DATABASE = 1;
enum OCI_HA_SOURCE_NODE = 2;
enum OCI_HA_SOURCE_SERVICE = 3;
enum OCI_HA_SOURCE_SERVICE_MEMBER = 4;
enum OCI_HA_SOURCE_ASM_INSTANCE = 5;
enum OCI_HA_SOURCE_SERVICE_PRECONNECT = 6;

enum OCI_ATTR_HA_STATUS = 402;
enum OCI_HA_STATUS_DOWN = 0; /* valid values for OCI_ATTR_HA_STATUS */
enum OCI_HA_STATUS_UP = 1;

enum OCI_ATTR_HA_SRVFIRST = 403;

enum OCI_ATTR_HA_SRVNEXT = 404;
/* ------------------------- Server Handle Attributes -----------------------*/

enum OCI_ATTR_TAF_ENABLED = 405;

/* Extra notification attributes */
enum OCI_ATTR_NFY_FLAGS = 406;

enum OCI_ATTR_MSG_DELIVERY_MODE = 407; /* msg delivery mode */
enum OCI_ATTR_DB_CHARSET_ID = 416; /* database charset ID */
enum OCI_ATTR_DB_NCHARSET_ID = 417; /* database ncharset ID */
enum OCI_ATTR_RESERVED_25 = 418; /* reserved */

enum OCI_ATTR_FLOW_CONTROL_TIMEOUT = 423; /* AQ: flow control timeout */
/*---------------------------------------------------------------------------*/
/* ------------------DirPathAPI attribute Section----------------------------*/
/* All DirPathAPI attributes are in this section of the file.  Existing      */
/* attributes prior to this section being created are assigned values < 2000 */
/* Add new DirPathAPI attributes to this section and their assigned value    */
/* should be whatever the last entry is + 1.                                 */

/*------------- Supported Values for Direct Path Stream Version -------------*/
enum OCI_DIRPATH_STREAM_VERSION_1 = 100;
enum OCI_DIRPATH_STREAM_VERSION_2 = 200;
enum OCI_DIRPATH_STREAM_VERSION_3 = 300; /* default */

enum OCI_ATTR_DIRPATH_MODE = 78; /* mode of direct path operation */
enum OCI_ATTR_DIRPATH_NOLOG = 79; /* nologging option */
enum OCI_ATTR_DIRPATH_PARALLEL = 80; /* parallel (temp seg) option */

enum OCI_ATTR_DIRPATH_SORTED_INDEX = 137; /* index that data is sorted on */

/* direct path index maint method (see oci8dp.h) */
enum OCI_ATTR_DIRPATH_INDEX_MAINT_METHOD = 138;

/* parallel load: db file, initial and next extent sizes */

enum OCI_ATTR_DIRPATH_FILE = 139; /* DB file to load into */
enum OCI_ATTR_DIRPATH_STORAGE_INITIAL = 140; /* initial extent size */
enum OCI_ATTR_DIRPATH_STORAGE_NEXT = 141; /* next extent size */
/* direct path index maint method (see oci8dp.h) */
enum OCI_ATTR_DIRPATH_SKIPINDEX_METHOD = 145;

/* 8.2 dpapi support of ADTs */
enum OCI_ATTR_DIRPATH_EXPR_TYPE = 150; /* expr type of OCI_ATTR_NAME */

/* For the direct path API there are three data formats:
 * TEXT   - used mainly by SQL*Loader, data is in textual form
 * STREAM - used by datapump, data is in stream loadable form
 * OCI    - used by OCI programs utilizing the DpApi, data is in binary form
 */
enum OCI_ATTR_DIRPATH_INPUT = 151;
enum OCI_DIRPATH_INPUT_TEXT = 0x01; /* text */
enum OCI_DIRPATH_INPUT_STREAM = 0x02; /* stream (datapump) */
enum OCI_DIRPATH_INPUT_OCI = 0x04; /* binary (oci) */
enum OCI_DIRPATH_INPUT_UNKNOWN = 0x08;

enum OCI_ATTR_DIRPATH_FN_CTX = 167; /* fn ctx ADT attrs or args */

enum OCI_ATTR_DIRPATH_OID = 187; /* loading into an OID col */
enum OCI_ATTR_DIRPATH_SID = 194; /* loading into an SID col */
enum OCI_ATTR_DIRPATH_OBJ_CONSTR = 206; /* obj type of subst obj tbl */

/* Attr to allow setting of the stream version PRIOR to calling Prepare */
enum OCI_ATTR_DIRPATH_STREAM_VERSION = 212; /* version of the stream*/

enum OCIP_ATTR_DIRPATH_VARRAY_INDEX = 213; /* varray index column */

/*------------- Supported Values for Direct Path Date cache -----------------*/
enum OCI_ATTR_DIRPATH_DCACHE_NUM = 303; /* date cache entries */
enum OCI_ATTR_DIRPATH_DCACHE_SIZE = 304; /* date cache limit */
enum OCI_ATTR_DIRPATH_DCACHE_MISSES = 305; /* date cache misses */
enum OCI_ATTR_DIRPATH_DCACHE_HITS = 306; /* date cache hits */
enum OCI_ATTR_DIRPATH_DCACHE_DISABLE = 307; /* on set: disable datecache
* on overflow.
* on get: datecache disabled?
* could be due to overflow
* or others                  */

/*------------- Attributes for 10i Updates to the DirPath API ---------------*/
enum OCI_ATTR_DIRPATH_RESERVED_7 = 326; /* reserved */
enum OCI_ATTR_DIRPATH_RESERVED_8 = 327; /* reserved */
enum OCI_ATTR_DIRPATH_CONVERT = 328; /* stream conversion needed? */
enum OCI_ATTR_DIRPATH_BADROW = 329; /* info about bad row */
enum OCI_ATTR_DIRPATH_BADROW_LENGTH = 330; /* length of bad row info */
enum OCI_ATTR_DIRPATH_WRITE_ORDER = 331; /* column fill order */
enum OCI_ATTR_DIRPATH_GRANULE_SIZE = 332; /* granule size for unload */
enum OCI_ATTR_DIRPATH_GRANULE_OFFSET = 333; /* offset to last granule */
enum OCI_ATTR_DIRPATH_RESERVED_1 = 334; /* reserved */
enum OCI_ATTR_DIRPATH_RESERVED_2 = 335; /* reserved */

/*------ Attributes for 10i DirPathAPI conversion (NLS lang, terr, cs) ------*/
enum OCI_ATTR_DIRPATH_RESERVED_3 = 337; /* reserved */
enum OCI_ATTR_DIRPATH_RESERVED_4 = 338; /* reserved */
enum OCI_ATTR_DIRPATH_RESERVED_5 = 357; /* reserved */
enum OCI_ATTR_DIRPATH_RESERVED_6 = 358; /* reserved */

enum OCI_ATTR_DIRPATH_LOCK_WAIT = 359; /* wait for lock in dpapi */

enum OCI_ATTR_DIRPATH_RESERVED_9 = 2000; /* reserved */

/*------ Attribute for 10iR2 for column encryption for Direct Path API ------*/
enum OCI_ATTR_DIRPATH_RESERVED_10 = 2001; /* reserved */
enum OCI_ATTR_DIRPATH_RESERVED_11 = 2002; /* reserved */

/*------ Attribute to determine last column successfully converted ----------*/
enum OCI_ATTR_CURRENT_ERRCOL = 2003; /* current error column */

/*--Attributes for 11gR1 for multiple subtype support in Direct Path API - */
enum OCI_ATTR_DIRPATH_SUBTYPE_INDEX = 2004; /* sbtyp indx for attribute */

enum OCI_ATTR_DIRPATH_RESERVED_12 = 2005; /* reserved */
enum OCI_ATTR_DIRPATH_RESERVED_13 = 2006; /* reserver */

/*--Attribute for partitioning constraint optimization in Direct Path API  */
enum OCI_ATTR_DIRPATH_RESERVED_14 = 2007; /* reserved */

/*--Attribute for interval partitioning in Direct Path API  */
enum OCI_ATTR_DIRPATH_RESERVED_15 = 2008; /* reserved */

/*--Attribute for interval partitioning in Direct Path API  */
enum OCI_ATTR_DIRPATH_RESERVED_16 = 2009; /* reserved */

/*--Attribute for allowing parallel lob loads in Direct Path API */
enum OCI_ATTR_DIRPATH_RESERVED_17 = 2010; /* reserved */

/*--Attribute for process order number of table being loaded/unloaded        */
enum OCI_ATTR_DIRPATH_RESERVED_18 = 2011; /* reserved */

enum OCI_ATTR_DIRPATH_RESERVED_19 = 2012; /* reserved */

enum OCI_ATTR_DIRPATH_NO_INDEX_ERRORS = 2013; /* reserved */

/*--Attribute for private sqlldr no index errors                             */
enum OCI_ATTR_DIRPATH_RESERVED_20 = 2014; /* reserved */

/*--Attribute for private sqlldr partition memory limit                      */
enum OCI_ATTR_DIRPATH_RESERVED_21 = 2015; /* reserved */

enum OCI_ATTR_DIRPATH_RESERVED_22 = 2016; /* reserved */

/* Add DirPathAPI attributes above.  Next value to be assigned is 2017      */

/* ------------------End of DirPathAPI attribute Section --------------------*/
/*---------------------------------------------------------------------------*/

/*---------------- Describe Handle Parameter Attribute Values ---------------*/

/* OCI_ATTR_CURSOR_COMMIT_BEHAVIOR */
enum OCI_CURSOR_OPEN = 0;
enum OCI_CURSOR_CLOSED = 1;

/* OCI_ATTR_CATALOG_LOCATION */
enum OCI_CL_START = 0;
enum OCI_CL_END = 1;

/* OCI_ATTR_SAVEPOINT_SUPPORT */
enum OCI_SP_SUPPORTED = 0;
enum OCI_SP_UNSUPPORTED = 1;

/* OCI_ATTR_NOWAIT_SUPPORT */
enum OCI_NW_SUPPORTED = 0;
enum OCI_NW_UNSUPPORTED = 1;

/* OCI_ATTR_AUTOCOMMIT_DDL */
enum OCI_AC_DDL = 0;
enum OCI_NO_AC_DDL = 1;

/* OCI_ATTR_LOCKING_MODE */
enum OCI_LOCK_IMMEDIATE = 0;
enum OCI_LOCK_DELAYED = 1;

/* ------------------- Instance type attribute values -----------------------*/
enum OCI_INSTANCE_TYPE_UNKNOWN = 0;
enum OCI_INSTANCE_TYPE_RDBMS = 1;
enum OCI_INSTANCE_TYPE_OSM = 2;

/* ---------------- ASM Volume Device Support attribute values --------------*/
enum OCI_ASM_VOLUME_UNSUPPORTED = 0;
enum OCI_ASM_VOLUME_SUPPORTED = 1;

/*---------------------------------------------------------------------------*/

/*---------------------------OCIPasswordChange-------------------------------*/
enum OCI_AUTH = 0x08; /* Change the password but do not login */

/*------------------------Other Constants------------------------------------*/
enum OCI_MAX_FNS = 100; /* max number of OCI Functions */
enum OCI_SQLSTATE_SIZE = 5;
enum OCI_ERROR_MAXMSG_SIZE = 1024; /* max size of an error message */
enum OCI_LOBMAXSIZE = MINUB4MAXVAL; /* maximum lob data size */
enum OCI_ROWID_LEN = 23;
enum OCI_LOB_CONTENTTYPE_MAXSIZE = 128; /* max size of securefile contenttype */
enum OCI_LOB_CONTENTTYPE_MAXBYTESIZE = OCI_LOB_CONTENTTYPE_MAXSIZE;
/*---------------------------------------------------------------------------*/

/*------------------------ Fail Over Events ---------------------------------*/
enum OCI_FO_END = 0x00000001;
enum OCI_FO_ABORT = 0x00000002;
enum OCI_FO_REAUTH = 0x00000004;
enum OCI_FO_BEGIN = 0x00000008;
enum OCI_FO_ERROR = 0x00000010;
/*---------------------------------------------------------------------------*/

/*------------------------ Fail Over Callback Return Codes ------------------*/
enum OCI_FO_RETRY = 25410;
/*---------------------------------------------------------------------------*/

/*------------------------- Fail Over Types ---------------------------------*/
enum OCI_FO_NONE = 0x00000001;
enum OCI_FO_SESSION = 0x00000002;
enum OCI_FO_SELECT = 0x00000004;
enum OCI_FO_TXNAL = 0x00000008;
/*---------------------------------------------------------------------------*/

/*-----------------------Function Codes--------------------------------------*/
enum OCI_FNCODE_INITIALIZE = 1; /* OCIInitialize */
enum OCI_FNCODE_HANDLEALLOC = 2; /* OCIHandleAlloc */
enum OCI_FNCODE_HANDLEFREE = 3; /* OCIHandleFree */
enum OCI_FNCODE_DESCRIPTORALLOC = 4; /* OCIDescriptorAlloc */
enum OCI_FNCODE_DESCRIPTORFREE = 5; /* OCIDescriptorFree */
enum OCI_FNCODE_ENVINIT = 6; /* OCIEnvInit */
enum OCI_FNCODE_SERVERATTACH = 7; /* OCIServerAttach */
enum OCI_FNCODE_SERVERDETACH = 8; /* OCIServerDetach */
/* unused         9 */
enum OCI_FNCODE_SESSIONBEGIN = 10; /* OCISessionBegin */
enum OCI_FNCODE_SESSIONEND = 11; /* OCISessionEnd */
enum OCI_FNCODE_PASSWORDCHANGE = 12; /* OCIPasswordChange */
enum OCI_FNCODE_STMTPREPARE = 13; /* OCIStmtPrepare */
/* unused       14- 16 */
enum OCI_FNCODE_BINDDYNAMIC = 17; /* OCIBindDynamic */
enum OCI_FNCODE_BINDOBJECT = 18; /* OCIBindObject */
/* 19 unused */
enum OCI_FNCODE_BINDARRAYOFSTRUCT = 20; /* OCIBindArrayOfStruct */
enum OCI_FNCODE_STMTEXECUTE = 21; /* OCIStmtExecute */
/* unused 22-24 */
enum OCI_FNCODE_DEFINEOBJECT = 25; /* OCIDefineObject */
enum OCI_FNCODE_DEFINEDYNAMIC = 26; /* OCIDefineDynamic */
enum OCI_FNCODE_DEFINEARRAYOFSTRUCT = 27; /* OCIDefineArrayOfStruct */
enum OCI_FNCODE_STMTFETCH = 28; /* OCIStmtFetch */
enum OCI_FNCODE_STMTGETBIND = 29; /* OCIStmtGetBindInfo */
/* 30, 31 unused */
enum OCI_FNCODE_DESCRIBEANY = 32; /* OCIDescribeAny */
enum OCI_FNCODE_TRANSSTART = 33; /* OCITransStart */
enum OCI_FNCODE_TRANSDETACH = 34; /* OCITransDetach */
enum OCI_FNCODE_TRANSCOMMIT = 35; /* OCITransCommit */
/* 36 unused */
enum OCI_FNCODE_ERRORGET = 37; /* OCIErrorGet */
enum OCI_FNCODE_LOBOPENFILE = 38; /* OCILobFileOpen */
enum OCI_FNCODE_LOBCLOSEFILE = 39; /* OCILobFileClose */
/* 40 was LOBCREATEFILE, unused */
/* 41 was OCILobFileDelete, unused  */
enum OCI_FNCODE_LOBCOPY = 42; /* OCILobCopy */
enum OCI_FNCODE_LOBAPPEND = 43; /* OCILobAppend */
enum OCI_FNCODE_LOBERASE = 44; /* OCILobErase */
enum OCI_FNCODE_LOBLENGTH = 45; /* OCILobGetLength */
enum OCI_FNCODE_LOBTRIM = 46; /* OCILobTrim */
enum OCI_FNCODE_LOBREAD = 47; /* OCILobRead */
enum OCI_FNCODE_LOBWRITE = 48; /* OCILobWrite */
/* 49 unused */
enum OCI_FNCODE_SVCCTXBREAK = 50; /* OCIBreak */
enum OCI_FNCODE_SERVERVERSION = 51; /* OCIServerVersion */

enum OCI_FNCODE_KERBATTRSET = 52; /* OCIKerbAttrSet */

/* unused 53 */

enum OCI_FNCODE_ATTRGET = 54; /* OCIAttrGet */
enum OCI_FNCODE_ATTRSET = 55; /* OCIAttrSet */
enum OCI_FNCODE_PARAMSET = 56; /* OCIParamSet */
enum OCI_FNCODE_PARAMGET = 57; /* OCIParamGet */
enum OCI_FNCODE_STMTGETPIECEINFO = 58; /* OCIStmtGetPieceInfo */
enum OCI_FNCODE_LDATOSVCCTX = 59; /* OCILdaToSvcCtx */
/* 60 unused */
enum OCI_FNCODE_STMTSETPIECEINFO = 61; /* OCIStmtSetPieceInfo */
enum OCI_FNCODE_TRANSFORGET = 62; /* OCITransForget */
enum OCI_FNCODE_TRANSPREPARE = 63; /* OCITransPrepare */
enum OCI_FNCODE_TRANSROLLBACK = 64; /* OCITransRollback */
enum OCI_FNCODE_DEFINEBYPOS = 65; /* OCIDefineByPos */
enum OCI_FNCODE_BINDBYPOS = 66; /* OCIBindByPos */
enum OCI_FNCODE_BINDBYNAME = 67; /* OCIBindByName */
enum OCI_FNCODE_LOBASSIGN = 68; /* OCILobAssign */
enum OCI_FNCODE_LOBISEQUAL = 69; /* OCILobIsEqual */
enum OCI_FNCODE_LOBISINIT = 70; /* OCILobLocatorIsInit */

enum OCI_FNCODE_LOBENABLEBUFFERING = 71; /* OCILobEnableBuffering */
enum OCI_FNCODE_LOBCHARSETID = 72; /* OCILobCharSetID */
enum OCI_FNCODE_LOBCHARSETFORM = 73; /* OCILobCharSetForm */
enum OCI_FNCODE_LOBFILESETNAME = 74; /* OCILobFileSetName */
enum OCI_FNCODE_LOBFILEGETNAME = 75; /* OCILobFileGetName */
enum OCI_FNCODE_LOGON = 76; /* OCILogon */
enum OCI_FNCODE_LOGOFF = 77; /* OCILogoff */
enum OCI_FNCODE_LOBDISABLEBUFFERING = 78; /* OCILobDisableBuffering */
enum OCI_FNCODE_LOBFLUSHBUFFER = 79; /* OCILobFlushBuffer */
enum OCI_FNCODE_LOBLOADFROMFILE = 80; /* OCILobLoadFromFile */

enum OCI_FNCODE_LOBOPEN = 81; /* OCILobOpen */
enum OCI_FNCODE_LOBCLOSE = 82; /* OCILobClose */
enum OCI_FNCODE_LOBISOPEN = 83; /* OCILobIsOpen */
enum OCI_FNCODE_LOBFILEISOPEN = 84; /* OCILobFileIsOpen */
enum OCI_FNCODE_LOBFILEEXISTS = 85; /* OCILobFileExists */
enum OCI_FNCODE_LOBFILECLOSEALL = 86; /* OCILobFileCloseAll */
enum OCI_FNCODE_LOBCREATETEMP = 87; /* OCILobCreateTemporary */
enum OCI_FNCODE_LOBFREETEMP = 88; /* OCILobFreeTemporary */
enum OCI_FNCODE_LOBISTEMP = 89; /* OCILobIsTemporary */

enum OCI_FNCODE_AQENQ = 90; /* OCIAQEnq */
enum OCI_FNCODE_AQDEQ = 91; /* OCIAQDeq */
enum OCI_FNCODE_RESET = 92; /* OCIReset */
enum OCI_FNCODE_SVCCTXTOLDA = 93; /* OCISvcCtxToLda */
enum OCI_FNCODE_LOBLOCATORASSIGN = 94; /* OCILobLocatorAssign */

enum OCI_FNCODE_UBINDBYNAME = 95;

enum OCI_FNCODE_AQLISTEN = 96; /* OCIAQListen */

enum OCI_FNCODE_SVC2HST = 97; /* reserved */
enum OCI_FNCODE_SVCRH = 98; /* reserved */
/* 97 and 98 are reserved for Oracle internal use */

enum OCI_FNCODE_TRANSMULTIPREPARE = 99; /* OCITransMultiPrepare */

enum OCI_FNCODE_CPOOLCREATE = 100; /* OCIConnectionPoolCreate */
enum OCI_FNCODE_CPOOLDESTROY = 101; /* OCIConnectionPoolDestroy */
enum OCI_FNCODE_LOGON2 = 102; /* OCILogon2 */
enum OCI_FNCODE_ROWIDTOCHAR = 103; /* OCIRowidToChar */

enum OCI_FNCODE_SPOOLCREATE = 104; /* OCISessionPoolCreate */
enum OCI_FNCODE_SPOOLDESTROY = 105; /* OCISessionPoolDestroy */
enum OCI_FNCODE_SESSIONGET = 106; /* OCISessionGet */
enum OCI_FNCODE_SESSIONRELEASE = 107; /* OCISessionRelease */
enum OCI_FNCODE_STMTPREPARE2 = 108; /* OCIStmtPrepare2 */
enum OCI_FNCODE_STMTRELEASE = 109; /* OCIStmtRelease */
enum OCI_FNCODE_AQENQARRAY = 110; /* OCIAQEnqArray */
enum OCI_FNCODE_AQDEQARRAY = 111; /* OCIAQDeqArray */
enum OCI_FNCODE_LOBCOPY2 = 112; /* OCILobCopy2 */
enum OCI_FNCODE_LOBERASE2 = 113; /* OCILobErase2 */
enum OCI_FNCODE_LOBLENGTH2 = 114; /* OCILobGetLength2 */
enum OCI_FNCODE_LOBLOADFROMFILE2 = 115; /* OCILobLoadFromFile2 */
enum OCI_FNCODE_LOBREAD2 = 116; /* OCILobRead2 */
enum OCI_FNCODE_LOBTRIM2 = 117; /* OCILobTrim2 */
enum OCI_FNCODE_LOBWRITE2 = 118; /* OCILobWrite2 */
enum OCI_FNCODE_LOBGETSTORAGELIMIT = 119; /* OCILobGetStorageLimit */
enum OCI_FNCODE_DBSTARTUP = 120; /* OCIDBStartup */
enum OCI_FNCODE_DBSHUTDOWN = 121; /* OCIDBShutdown */
enum OCI_FNCODE_LOBARRAYREAD = 122; /* OCILobArrayRead */
enum OCI_FNCODE_LOBARRAYWRITE = 123; /* OCILobArrayWrite */
enum OCI_FNCODE_AQENQSTREAM = 124; /* OCIAQEnqStreaming */
enum OCI_FNCODE_AQGETREPLAY = 125; /* OCIAQGetReplayInfo */
enum OCI_FNCODE_AQRESETREPLAY = 126; /* OCIAQResetReplayInfo */
enum OCI_FNCODE_ARRAYDESCRIPTORALLOC = 127; /*OCIArrayDescriptorAlloc */
enum OCI_FNCODE_ARRAYDESCRIPTORFREE = 128; /* OCIArrayDescriptorFree  */
enum OCI_FNCODE_LOBGETOPT = 129; /* OCILobGetCptions */
enum OCI_FNCODE_LOBSETOPT = 130; /* OCILobSetCptions */
enum OCI_FNCODE_LOBFRAGINS = 131; /* OCILobFragementInsert */
enum OCI_FNCODE_LOBFRAGDEL = 132; /* OCILobFragementDelete */
enum OCI_FNCODE_LOBFRAGMOV = 133; /* OCILobFragementMove */
enum OCI_FNCODE_LOBFRAGREP = 134; /* OCILobFragementReplace */
enum OCI_FNCODE_LOBGETDEDUPLICATEREGIONS = 135; /* OCILobGetDeduplicateRegions */
enum OCI_FNCODE_APPCTXSET = 136; /* OCIAppCtxSet */
enum OCI_FNCODE_APPCTXCLEARALL = 137; /* OCIAppCtxClearAll */

enum OCI_FNCODE_LOBGETCONTENTTYPE = 138; /* OCILobGetContentType */
enum OCI_FNCODE_LOBSETCONTENTTYPE = 139; /* OCILobSetContentType */
enum OCI_FNCODE_MAXFCN = 139; /* maximum OCI function code */

/*---------------Statement Cache callback modes-----------------------------*/
enum OCI_CBK_STMTCACHE_STMTPURGE = 0x01;

/*---------------------------------------------------------------------------*/

/*-----------------------Handle Definitions----------------------------------*/
struct OCIEnv; /* OCI environment handle */
struct OCIError; /* OCI error handle */
struct OCISvcCtx; /* OCI service handle */
struct OCIStmt; /* OCI statement handle */
struct OCIBind; /* OCI bind handle */
struct OCIDefine; /* OCI Define handle */
struct OCIDescribe; /* OCI Describe handle */
struct OCIServer; /* OCI Server handle */
struct OCISession; /* OCI Authentication handle */
struct OCIComplexObject; /* OCI COR handle */
struct OCITrans; /* OCI Transaction handle */
struct OCISecurity; /* OCI Security handle */
struct OCISubscription; /* subscription handle */

struct OCICPool; /* connection pool handle */
struct OCISPool; /* session pool handle */
struct OCIAuthInfo; /* auth handle */
struct OCIAdmin; /* admin handle */
struct OCIEvent; /* HA event handle */

/*-----------------------Descriptor Definitions------------------------------*/
struct OCISnapshot; /* OCI snapshot descriptor */
struct OCIResult; /* OCI Result Set Descriptor */
struct OCILobLocator; /* OCI Lob Locator descriptor */
struct OCILobRegion; /* OCI Lob Regions descriptor */
struct OCIParam; /* OCI PARameter descriptor */
struct OCIComplexObjectComp;
/* OCI COR descriptor */
struct OCIRowid; /* OCI ROWID descriptor */

struct OCIDateTime; /* OCI DateTime descriptor */
struct OCIInterval; /* OCI Interval descriptor */

struct OCIUcb; /* OCI User Callback descriptor */
struct OCIServerDNs; /* OCI server DN descriptor */

/*-------------------------- AQ Descriptors ---------------------------------*/
struct OCIAQEnqOptions; /* AQ Enqueue Options hdl */
struct OCIAQDeqOptions; /* AQ Dequeue Options hdl */
struct OCIAQMsgProperties; /* AQ Mesg Properties */
struct OCIAQAgent; /* AQ Agent descriptor */
struct OCIAQNfyDescriptor; /* AQ Nfy descriptor */
struct OCIAQSignature; /* AQ Siganture */
struct OCIAQListenOpts; /* AQ listen options */
struct OCIAQLisMsgProps; /* AQ listen msg props */

/*---------------------------------------------------------------------------*/

/* Lob typedefs for Pro*C */
alias OCIClobLocator = OCILobLocator; /* OCI Character LOB Locator */
alias OCIBlobLocator = OCILobLocator; /* OCI Binary LOB Locator */
alias OCIBFileLocator = OCILobLocator; /* OCI Binary LOB File Locator */
/*---------------------------------------------------------------------------*/

/* Undefined value for tz in interval types*/
enum OCI_INTHR_UNK = 24;

/* These defined adjustment values */
enum OCI_ADJUST_UNK = 10;
enum OCI_ORACLE_DATE = 0;
enum OCI_ANSI_DATE = 1;

/*------------------------ Lob-specific Definitions -------------------------*/

/*
 * ociloff - OCI Lob OFFset
 *
 * The offset in the lob data.  The offset is specified in terms of bytes for
 * BLOBs and BFILes.  Character offsets are used for CLOBs, NCLOBs.
 * The maximum size of internal lob data is 4 gigabytes.  FILE LOB
 * size is limited by the operating system.
 */
alias OCILobOffset = uint;

/*
 * ocillen - OCI Lob LENgth (of lob data)
 *
 * Specifies the length of lob data in bytes for BLOBs and BFILes and in
 * characters for CLOBs, NCLOBs.  The maximum length of internal lob
 * data is 4 gigabytes.  The length of FILE LOBs is limited only by the
 * operating system.
 */
alias OCILobLength = uint;
/*
 * ocilmo - OCI Lob open MOdes
 *
 * The mode specifies the planned operations that will be performed on the
 * FILE lob data.  The FILE lob can be opened in read-only mode only.
 *
 * In the future, we may include read/write, append and truncate modes.  Append
 * is equivalent to read/write mode except that the FILE is positioned for
 * writing to the end.  Truncate is equivalent to read/write mode except that
 * the FILE LOB data is first truncated to a length of 0 before use.
 */
enum OCILobMode
{
    OCI_LOBMODE_READONLY = 1, /* read-only */
    OCI_LOBMODE_READWRITE = 2 /* read_write for internal lobs only */
}

/*---------------------------------------------------------------------------*/

/*----------------------------Piece Definitions------------------------------*/

/* if ocidef.h is being included in the app, ocidef.h should precede oci.h */

/*
 * since clients may  use oci.h, ocidef.h and ocidfn.h the following defines
 * need to be guarded, usually internal clients
 */

/* one piece */
/* the first piece */
/* the next of many pieces */
/* the last piece */

/*---------------------------------------------------------------------------*/

/*--------------------------- FILE open modes -------------------------------*/
enum OCI_FILE_READONLY = 1; /* readonly mode open for FILE types */
/*---------------------------------------------------------------------------*/
/*--------------------------- LOB open modes --------------------------------*/
enum OCI_LOB_READONLY = 1; /* readonly mode open for ILOB types */
enum OCI_LOB_READWRITE = 2; /* read write mode open for ILOBs */
enum OCI_LOB_WRITEONLY = 3; /* Writeonly mode open for ILOB types*/
enum OCI_LOB_APPENDONLY = 4; /* Appendonly mode open for ILOB types */
enum OCI_LOB_FULLOVERWRITE = 5; /* Completely overwrite ILOB */
enum OCI_LOB_FULLREAD = 6; /* Doing a Full Read of ILOB */

/*----------------------- LOB Buffering Flush Flags -------------------------*/
enum OCI_LOB_BUFFER_FREE = 1;
enum OCI_LOB_BUFFER_NOFREE = 2;
/*---------------------------------------------------------------------------*/

/*---------------------------LOB Option Types -------------------------------*/
enum OCI_LOB_OPT_COMPRESS = 1; /* SECUREFILE Compress */
enum OCI_LOB_OPT_ENCRYPT = 2; /* SECUREFILE Encrypt */
enum OCI_LOB_OPT_DEDUPLICATE = 4; /* SECUREFILE Deduplicate */
enum OCI_LOB_OPT_ALLOCSIZE = 8; /* SECUREFILE Allocation Size */
enum OCI_LOB_OPT_CONTENTTYPE = 16; /* SECUREFILE Content Type */
enum OCI_LOB_OPT_MODTIME = 32; /* SECUREFILE Modification Time */

/*------------------------   LOB Option Values ------------------------------*/
/* Compression */
enum OCI_LOB_COMPRESS_OFF = 0; /* Compression off */
enum OCI_LOB_COMPRESS_ON = 1; /* Compression on */
/* Encryption */
enum OCI_LOB_ENCRYPT_OFF = 0; /* Encryption Off */
enum OCI_LOB_ENCRYPT_ON = 2; /* Encryption On */
/* Deduplciate */
enum OCI_LOB_DEDUPLICATE_OFF = 0; /* Deduplicate Off */
enum OCI_LOB_DEDUPLICATE_ON = 4; /* Deduplicate Lobs */

/*--------------------------- OCI Statement Types ---------------------------*/

enum OCI_STMT_UNKNOWN = 0; /* Unknown statement */
enum OCI_STMT_SELECT = 1; /* select statement */
enum OCI_STMT_UPDATE = 2; /* update statement */
enum OCI_STMT_DELETE = 3; /* delete statement */
enum OCI_STMT_INSERT = 4; /* Insert Statement */
enum OCI_STMT_CREATE = 5; /* create statement */
enum OCI_STMT_DROP = 6; /* drop statement */
enum OCI_STMT_ALTER = 7; /* alter statement */
enum OCI_STMT_BEGIN = 8; /* begin ... (pl/sql statement)*/
enum OCI_STMT_DECLARE = 9; /* declare .. (pl/sql statement ) */
enum OCI_STMT_CALL = 10; /* corresponds to kpu call */
/*---------------------------------------------------------------------------*/

/*--------------------------- OCI Parameter Types ---------------------------*/
enum OCI_PTYPE_UNK = 0; /* unknown   */
enum OCI_PTYPE_TABLE = 1; /* table     */
enum OCI_PTYPE_VIEW = 2; /* view      */
enum OCI_PTYPE_PROC = 3; /* procedure */
enum OCI_PTYPE_FUNC = 4; /* function  */
enum OCI_PTYPE_PKG = 5; /* package   */
enum OCI_PTYPE_TYPE = 6; /* user-defined type */
enum OCI_PTYPE_SYN = 7; /* synonym   */
enum OCI_PTYPE_SEQ = 8; /* sequence  */
enum OCI_PTYPE_COL = 9; /* column    */
enum OCI_PTYPE_ARG = 10; /* argument  */
enum OCI_PTYPE_LIST = 11; /* list      */
enum OCI_PTYPE_TYPE_ATTR = 12; /* user-defined type's attribute */
enum OCI_PTYPE_TYPE_COLL = 13; /* collection type's element */
enum OCI_PTYPE_TYPE_METHOD = 14; /* user-defined type's method */
enum OCI_PTYPE_TYPE_ARG = 15; /* user-defined type method's arg */
enum OCI_PTYPE_TYPE_RESULT = 16; /* user-defined type method's result */
enum OCI_PTYPE_SCHEMA = 17; /* schema */
enum OCI_PTYPE_DATABASE = 18; /* database */
enum OCI_PTYPE_RULE = 19; /* rule */
enum OCI_PTYPE_RULE_SET = 20; /* rule set */
enum OCI_PTYPE_EVALUATION_CONTEXT = 21; /* evaluation context */
enum OCI_PTYPE_TABLE_ALIAS = 22; /* table alias */
enum OCI_PTYPE_VARIABLE_TYPE = 23; /* variable type */
enum OCI_PTYPE_NAME_VALUE = 24; /* name value pair */

/*---------------------------------------------------------------------------*/

/*----------------------------- OCI List Types ------------------------------*/
enum OCI_LTYPE_UNK = 0; /* unknown   */
enum OCI_LTYPE_COLUMN = 1; /* column list */
enum OCI_LTYPE_ARG_PROC = 2; /* procedure argument list */
enum OCI_LTYPE_ARG_FUNC = 3; /* function argument list */
enum OCI_LTYPE_SUBPRG = 4; /* subprogram list */
enum OCI_LTYPE_TYPE_ATTR = 5; /* type attribute */
enum OCI_LTYPE_TYPE_METHOD = 6; /* type method */
enum OCI_LTYPE_TYPE_ARG_PROC = 7; /* type method w/o result argument list */
enum OCI_LTYPE_TYPE_ARG_FUNC = 8; /* type method w/result argument list */
enum OCI_LTYPE_SCH_OBJ = 9; /* schema object list */
enum OCI_LTYPE_DB_SCH = 10; /* database schema list */
enum OCI_LTYPE_TYPE_SUBTYPE = 11; /* subtype list */
enum OCI_LTYPE_TABLE_ALIAS = 12; /* table alias list */
enum OCI_LTYPE_VARIABLE_TYPE = 13; /* variable type list */
enum OCI_LTYPE_NAME_VALUE = 14; /* name value list */

/*---------------------------------------------------------------------------*/

/*-------------------------- Memory Cartridge Services ---------------------*/
enum OCI_MEMORY_CLEARED = 1;

/*-------------------------- Pickler Cartridge Services ---------------------*/
struct OCIPicklerTdsCtx;
struct OCIPicklerTds;
struct OCIPicklerImage;
struct OCIPicklerFdo;
alias OCIPicklerTdsElement = uint;

struct OCIAnyData;

struct OCIAnyDataSet;
struct OCIAnyDataCtx;

/*---------------------------------------------------------------------------*/

/*--------------------------- User Callback Constants -----------------------*/
enum OCI_UCBTYPE_ENTRY = 1; /* entry callback */
enum OCI_UCBTYPE_EXIT = 2; /* exit callback */
enum OCI_UCBTYPE_REPLACE = 3; /* replacement callback */

/*---------------------------------------------------------------------------*/

/*--------------------- NLS service type and constance ----------------------*/
enum OCI_NLS_DAYNAME1 = 1; /* Native name for Monday */
enum OCI_NLS_DAYNAME2 = 2; /* Native name for Tuesday */
enum OCI_NLS_DAYNAME3 = 3; /* Native name for Wednesday */
enum OCI_NLS_DAYNAME4 = 4; /* Native name for Thursday */
enum OCI_NLS_DAYNAME5 = 5; /* Native name for Friday */
enum OCI_NLS_DAYNAME6 = 6; /* Native name for for Saturday */
enum OCI_NLS_DAYNAME7 = 7; /* Native name for for Sunday */
enum OCI_NLS_ABDAYNAME1 = 8; /* Native abbreviated name for Monday */
enum OCI_NLS_ABDAYNAME2 = 9; /* Native abbreviated name for Tuesday */
enum OCI_NLS_ABDAYNAME3 = 10; /* Native abbreviated name for Wednesday */
enum OCI_NLS_ABDAYNAME4 = 11; /* Native abbreviated name for Thursday */
enum OCI_NLS_ABDAYNAME5 = 12; /* Native abbreviated name for Friday */
enum OCI_NLS_ABDAYNAME6 = 13; /* Native abbreviated name for for Saturday */
enum OCI_NLS_ABDAYNAME7 = 14; /* Native abbreviated name for for Sunday */
enum OCI_NLS_MONTHNAME1 = 15; /* Native name for January */
enum OCI_NLS_MONTHNAME2 = 16; /* Native name for February */
enum OCI_NLS_MONTHNAME3 = 17; /* Native name for March */
enum OCI_NLS_MONTHNAME4 = 18; /* Native name for April */
enum OCI_NLS_MONTHNAME5 = 19; /* Native name for May */
enum OCI_NLS_MONTHNAME6 = 20; /* Native name for June */
enum OCI_NLS_MONTHNAME7 = 21; /* Native name for July */
enum OCI_NLS_MONTHNAME8 = 22; /* Native name for August */
enum OCI_NLS_MONTHNAME9 = 23; /* Native name for September */
enum OCI_NLS_MONTHNAME10 = 24; /* Native name for October */
enum OCI_NLS_MONTHNAME11 = 25; /* Native name for November */
enum OCI_NLS_MONTHNAME12 = 26; /* Native name for December */
enum OCI_NLS_ABMONTHNAME1 = 27; /* Native abbreviated name for January */
enum OCI_NLS_ABMONTHNAME2 = 28; /* Native abbreviated name for February */
enum OCI_NLS_ABMONTHNAME3 = 29; /* Native abbreviated name for March */
enum OCI_NLS_ABMONTHNAME4 = 30; /* Native abbreviated name for April */
enum OCI_NLS_ABMONTHNAME5 = 31; /* Native abbreviated name for May */
enum OCI_NLS_ABMONTHNAME6 = 32; /* Native abbreviated name for June */
enum OCI_NLS_ABMONTHNAME7 = 33; /* Native abbreviated name for July */
enum OCI_NLS_ABMONTHNAME8 = 34; /* Native abbreviated name for August */
enum OCI_NLS_ABMONTHNAME9 = 35; /* Native abbreviated name for September */
enum OCI_NLS_ABMONTHNAME10 = 36; /* Native abbreviated name for October */
enum OCI_NLS_ABMONTHNAME11 = 37; /* Native abbreviated name for November */
enum OCI_NLS_ABMONTHNAME12 = 38; /* Native abbreviated name for December */
enum OCI_NLS_YES = 39; /* Native string for affirmative response */
enum OCI_NLS_NO = 40; /* Native negative response */
enum OCI_NLS_AM = 41; /* Native equivalent string of AM */
enum OCI_NLS_PM = 42; /* Native equivalent string of PM */
enum OCI_NLS_AD = 43; /* Native equivalent string of AD */
enum OCI_NLS_BC = 44; /* Native equivalent string of BC */
enum OCI_NLS_DECIMAL = 45; /* decimal character */
enum OCI_NLS_GROUP = 46; /* group separator */
enum OCI_NLS_DEBIT = 47; /* Native symbol of debit */
enum OCI_NLS_CREDIT = 48; /* Native sumbol of credit */
enum OCI_NLS_DATEFORMAT = 49; /* Oracle date format */
enum OCI_NLS_INT_CURRENCY = 50; /* International currency symbol */
enum OCI_NLS_LOC_CURRENCY = 51; /* Locale currency symbol */
enum OCI_NLS_LANGUAGE = 52; /* Language name */
enum OCI_NLS_ABLANGUAGE = 53; /* Abbreviation for language name */
enum OCI_NLS_TERRITORY = 54; /* Territory name */
enum OCI_NLS_CHARACTER_SET = 55; /* Character set name */
enum OCI_NLS_LINGUISTIC_NAME = 56; /* Linguistic name */
enum OCI_NLS_CALENDAR = 57; /* Calendar name */
enum OCI_NLS_DUAL_CURRENCY = 78; /* Dual currency symbol */
enum OCI_NLS_WRITINGDIR = 79; /* Language writing direction */
enum OCI_NLS_ABTERRITORY = 80; /* Territory Abbreviation */
enum OCI_NLS_DDATEFORMAT = 81; /* Oracle default date format */
enum OCI_NLS_DTIMEFORMAT = 82; /* Oracle default time format */
enum OCI_NLS_SFDATEFORMAT = 83; /* Local string formatted date format */
enum OCI_NLS_SFTIMEFORMAT = 84; /* Local string formatted time format */
enum OCI_NLS_NUMGROUPING = 85; /* Number grouping fields */
enum OCI_NLS_LISTSEP = 86; /* List separator */
enum OCI_NLS_MONDECIMAL = 87; /* Monetary decimal character */
enum OCI_NLS_MONGROUP = 88; /* Monetary group separator */
enum OCI_NLS_MONGROUPING = 89; /* Monetary grouping fields */
enum OCI_NLS_INT_CURRENCYSEP = 90; /* International currency separator */
enum OCI_NLS_CHARSET_MAXBYTESZ = 91; /* Maximum character byte size      */
enum OCI_NLS_CHARSET_FIXEDWIDTH = 92; /* Fixed-width charset byte size    */
enum OCI_NLS_CHARSET_ID = 93; /* Character set id */
enum OCI_NLS_NCHARSET_ID = 94; /* NCharacter set id */

enum OCI_NLS_MAXBUFSZ = 100; /* Max buffer size may need for OCINlsGetInfo */

enum OCI_NLS_BINARY = 0x1; /* for the binary comparison */
enum OCI_NLS_LINGUISTIC = 0x2; /* for linguistic comparison */
enum OCI_NLS_CASE_INSENSITIVE = 0x10; /* for case-insensitive comparison */

enum OCI_NLS_UPPERCASE = 0x20; /* convert to uppercase */
enum OCI_NLS_LOWERCASE = 0x40; /* convert to lowercase */

enum OCI_NLS_CS_IANA_TO_ORA = 0; /* Map charset name from IANA to Oracle */
enum OCI_NLS_CS_ORA_TO_IANA = 1; /* Map charset name from Oracle to IANA */
enum OCI_NLS_LANG_ISO_TO_ORA = 2; /* Map language name from ISO to Oracle */
enum OCI_NLS_LANG_ORA_TO_ISO = 3; /* Map language name from Oracle to ISO */
enum OCI_NLS_TERR_ISO_TO_ORA = 4; /* Map territory name from ISO to Oracle*/
enum OCI_NLS_TERR_ORA_TO_ISO = 5; /* Map territory name from Oracle to ISO*/
enum OCI_NLS_TERR_ISO3_TO_ORA = 6; /* Map territory name from 3-letter ISO */
/* abbreviation to Oracle               */
enum OCI_NLS_TERR_ORA_TO_ISO3 = 7; /* Map territory name from Oracle to    */
/* 3-letter ISO abbreviation            */
enum OCI_NLS_LOCALE_A2_ISO_TO_ORA = 8;
/*Map locale name from A2 ISO to oracle*/
enum OCI_NLS_LOCALE_A2_ORA_TO_ISO = 9;
/*Map locale name from oracle to A2 ISO*/

struct OCIMsg;
alias OCIWchar = uint;

enum OCI_XMLTYPE_CREATE_OCISTRING = 1;
enum OCI_XMLTYPE_CREATE_CLOB = 2;
enum OCI_XMLTYPE_CREATE_BLOB = 3;

/*------------------------- Kerber Authentication Modes ---------------------*/
enum OCI_KERBCRED_PROXY = 1; /* Apply Kerberos Creds for Proxy */
enum OCI_KERBCRED_CLIENT_IDENTIFIER = 2; /*Apply Creds for Secure Client ID */

/*------------------------- Database Startup Flags --------------------------*/
enum OCI_DBSTARTUPFLAG_FORCE = 0x00000001; /* Abort running instance, start */
enum OCI_DBSTARTUPFLAG_RESTRICT = 0x00000002; /* Restrict access to DBA */

/*------------------------- Database Shutdown Modes -------------------------*/
enum OCI_DBSHUTDOWN_TRANSACTIONAL = 1; /* Wait for all the transactions */
enum OCI_DBSHUTDOWN_TRANSACTIONAL_LOCAL = 2; /* Wait for local transactions */
enum OCI_DBSHUTDOWN_IMMEDIATE = 3; /* Terminate and roll back */
enum OCI_DBSHUTDOWN_ABORT = 4; /* Terminate and don't roll back */
enum OCI_DBSHUTDOWN_FINAL = 5; /* Orderly shutdown */

/*------------------------- Version information -----------------------------*/
enum OCI_MAJOR_VERSION = 11; /* Major release version */
enum OCI_MINOR_VERSION = 2; /* Minor release version */

/*---------------------- OCIIOV structure definitions -----------------------*/
struct OCIIOV
{
    void* bfp; /* The Pointer to the data buffer */
    ub4 bfl; /* Length of the Data Buffer */
}

/*---------------------------------------------------------------------------
                     PRIVATE TYPES AND CONSTANTS
  ---------------------------------------------------------------------------*/

/* None */

/*---------------------------------------------------------------------------
                           PUBLIC FUNCTIONS
  ---------------------------------------------------------------------------*/

/* see ociap.h or ocikp.h */

/*---------------------------------------------------------------------------
                          PRIVATE FUNCTIONS
  ---------------------------------------------------------------------------*/

/* None */

/* OCI_ORACLE */

/* more includes */

/* interface definitions for the direct path api */

/* __cplusplus */
