module oracle;

import std.array : array, appender;
import std.algorithm : max, min, map;
import std.concurrency : thisTid, Tid, send, receive, receiveTimeout, OwnerTerminated, LinkTerminated, prioritySend;
import std.conv : to;
import std.datetime;
import std.datetime.stopwatch : StopWatch, AutoStart;
import std.format : format;
import std.range : iota;
import std.sumtype : SumType, match, tryMatch;
import std.string : toStringz, fromStringz, indexOf, splitLines, rightJustify, leftJustify, replace;
import std.traits : isIntegral, isPointer, isSigned, isFloatingPoint, PointerTarget, TemplateArgsOf, Unqual;
import std.typecons : Tuple, isTuple, Nullable;
import std.variant : Variant;

import core.thread;

//import std.conv;
//import std.stdio : write, writeln, readln;
//import std.sumtype : SumType, match;
//import std.typecons;
//import std.variant;
import core.memory;

import oratypes : oracleString = string;
//import nzerror_module;
import nzt;
import oci;
//import oci1;
//import oci8dp;
import ociap;
//import ociapr;
//import ocidem;
import ocidfn;
//import ociextp;
//import ocikpr;
//import ocixmldb;
//import ocixstream;
//import odci;
import ori;
//import orid;
import orl;
import oro;
import ort;
//import xa;

import program;
import range_extensions;
import utf8_slice;

// For this to work, the following the Oracle OCI Instant Client Light is required:
//    
//    This is the lightest native OCI Oracle Driver I could find.  It 
//    can be xcopy deployed according to:
//    
//      https://docs.oracle.com/en/database/oracle/oracle-database/12.2/lnoci/instant-client.html#GUID-E436205F-2A39-45AC-BD28-969D4B74128B
//    
//    HOWEVER, make sure you are looking at section "2.2.2 Operation of 
//    Instant Client Light" and not "2.1 About OCI Instant Client" 
//    because I lost some time based on the two similar looking tables.
//    
//    In section 2.2.2, it lists the core files required by the OCI Instant
//    Instant client light.  See below for my understanding.
//    
// All the above are stored in the following files:
// 
// File              Deloy? Description
// ~~~~~~~~~~~~~~~~~ ~~~~~~ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// oci.dll           Yes    Instant Client Light (Forwarding functions that applications link with)
// orannzsbb18.dll   Yes    Instant Client Light (Security Library)
// oraociicus18.dll  Yes    Instant Client Light (Data and code)
// 
// oci.sym           Yes    Instant Client Light Symbols
// orannzsbb18.sym   Yes    Instant Client Light Symbols
// oraociicus18.sym  Yes    Instant Client Light Symbols
// 
// tnsnames.ora      Maybe  This can go in the target directory, or you can specify 
//                          the TNSNames directly in the connection.

private class InstructionCancelledException : RecoverableException 
{  
    this() @nogc nothrow
    {
        super("Cancelled");
    }
}

private class WorkerKilledException : RecoverableException 
{  
    this() @nogc nothrow
    {
        super("Killed");
    }
}

private final class OracleException : Exception
{
    private immutable int code;
    
    private this(string description, string file, size_t line, int code = 0) @nogc nothrow
    {
        this.code = code;
        super(description, file, line);
    }
}

private template handleType(alias handle)
{
    static if (is(handle))
        alias THandleType = handle;
    else static if (isPointer!(typeof(handle)))
        alias THandleType = PointerTarget!(typeof(handle));
    else
        alias THandleType = typeof(handle);
    
         static if (is(THandleType == OCIEnv             )) enum handleType = OCI_HTYPE_ENV;
    else static if (is(THandleType == OCIError           )) enum handleType = OCI_HTYPE_ERROR;
    else static if (is(THandleType == OCISvcCtx          )) enum handleType = OCI_HTYPE_SVCCTX;
    else static if (is(THandleType == OCIStmt            )) enum handleType = OCI_HTYPE_STMT;
    else static if (is(THandleType == OCIBind            )) enum handleType = OCI_HTYPE_BIND;
    else static if (is(THandleType == OCIDefine          )) enum handleType = OCI_HTYPE_DEFINE;
    else static if (is(THandleType == OCIDescribe        )) enum handleType = OCI_HTYPE_DESCRIBE;
    else static if (is(THandleType == OCIServer          )) enum handleType = OCI_HTYPE_SERVER;
    else static if (is(THandleType == OCISession         )) enum handleType = OCI_HTYPE_SESSION;
    else static if (is(THandleType == OCIAuthInfo        )) enum handleType = OCI_HTYPE_AUTHINFO;
    else static if (is(THandleType == OCICPool           )) enum handleType = OCI_HTYPE_CPOOL;
    else static if (is(THandleType == OCISPool           )) enum handleType = OCI_HTYPE_SPOOL;
    else static if (is(THandleType == OCITrans           )) enum handleType = OCI_HTYPE_TRANS;
    else static if (is(THandleType == OCIComplexObject   )) enum handleType = OCI_HTYPE_COMPLEXOBJECT;
    else static if (is(THandleType == OCISubscription    )) enum handleType = OCI_HTYPE_SUBSCRIPTION;
 // else static if (is(THandleType == OCIDirPathCtx      )) enum handleType = OCI_HTYPE_DIRPATH_CTX;
 // else static if (is(THandleType == OCIDirPathFuncCtx  )) enum handleType = OCI_HTYPE_DIRPATH_FN_CTX;
 // else static if (is(THandleType == OCIDirPathColArray )) enum handleType = OCI_HTYPE_DIRPATH_COLUMN_ARRAY;
 // else static if (is(THandleType == OCIDirPathStream   )) enum handleType = OCI_HTYPE_DIRPATH_STREAM;
    else static if (is(THandleType == OCIParam           )) enum handleType = OCI_DTYPE_PARAM;
    else static if (is(THandleType == OCILobLocator      )) enum handleType = OCI_DTYPE_LOB;
    else static if (is(THandleType == OCIRowid           )) enum handleType = OCI_DTYPE_ROWID;
    else static if (is(THandleType == OCIDateTime        )) enum handleType = OCI_DTYPE_TIMESTAMP;
    else static if (is(THandleType == OCIDateTime        )) enum handleType = OCI_DTYPE_TIMESTAMP_TZ;
    else static if (is(THandleType == OCIDateTime        )) enum handleType = OCI_DTYPE_TIMESTAMP_LTZ;
    else static if (is(THandleType == OCIInterval        )) enum handleType = OCI_DTYPE_INTERVAL_DS;
    else static if (is(THandleType == OCIInterval        )) enum handleType = OCI_DTYPE_INTERVAL_YM;
    
    else static assert(false, "Cannot find matching handle ID.  Handle " ~ THandleType.stringof ~ " is not a valid Oracle handle type.");   
}

private enum IntermediateType {Unsupported, String, Number, DateTime, Descriptor}
private enum DescriptorCategory {None, Lob, DateTime, Interval}

private void checkResult(T)(
    const uint result, 
    const T* error, 
    void delegate(string) processWarning = null, 
    string file = __FILE__, 
    size_t line = __LINE__) @trusted
    if (is(T == OCIError) || is(T == OCIEnv))
{
    switch (result)
    {
        case OCI_SUCCESS:
            return;
        
        case OCI_ERROR, OCI_SUCCESS_WITH_INFO:
            int errorCode;
            uint errorMessageSize;
            uint lineNumber = 1;
            size_t errorStartOffset = 0;
            
            static char[4096] errorMessage;
            errorMessage = '\0';
            
            while (true)
            {
                int lastErrorCode;
                immutable getErrorResult = OCIErrorGet(
                    cast(void*)error, 
                    lineNumber, 
                    null, 
                    &lastErrorCode, 
                    cast(ubyte*)errorMessage[errorStartOffset .. $].ptr, 
                    cast(uint)(errorMessage.length - errorStartOffset),  
                    handleType!T);
                
                if (getErrorResult == OCI_NO_DATA)
                    break;
                
                // The last entry can contain 100 (OCI_NO_DATA) so only use it if data was returned.
                errorCode = lastErrorCode; 
                
                if (getErrorResult != OCI_SUCCESS)
                    throw new OracleException("Error (" ~ getErrorResult.to!string ~ ") when trying to extract error information.", file, line, errorCode);
                
                immutable errorMessageLength = ()
                    {
                        foreach (i, c; errorMessage[errorStartOffset .. $])
                            if (c == '\0')
                                return i;
                        
                        return errorMessage[errorStartOffset .. $].length;
                    }();
                
                errorStartOffset += errorMessageLength;
                if (errorStartOffset >= errorMessage.length)
                    break;
                
                if (errorStartOffset > 0 && 
                    errorStartOffset < errorMessage.length - 1 && 
                    errorMessage[errorStartOffset - 1] != '\n')
                {
                    errorMessage[errorStartOffset] = '\n';
                    errorStartOffset++;
                    errorMessage[errorStartOffset] = '\0';
                }
                
                lineNumber++;
            }
            
            if (errorStartOffset == 0)
                throw new OracleException("Oracle error returned with no error detail.", file, line, errorCode);
            else if (result != OCI_SUCCESS_WITH_INFO || processWarning is null)
                throw new OracleException(errorMessage[0 .. errorStartOffset].to!string, file, line, errorCode);
            
            processWarning(errorMessage[0 .. errorStartOffset].to!string);
            return;
            
        case OCI_NEED_DATA:
            throw new OracleException("Runtime data required.", file, line);
            
        case OCI_NO_DATA:
            throw new OracleException("ORA-01403: no data found", file, line, 1403);
            
        case OCI_RESERVED_FOR_INT_USE:
            throw new OracleException("This error code was reserved by Oracle for their internal use.", file, line);
            
        case OCI_INVALID_HANDLE:
            throw new OracleException("An invalid handle was passed as a parameter or a user callback is passed an invalid handle or invalid context.  No further diagnostics are available.", file, line);
            
        case OCI_STILL_EXECUTING:
            throw new OracleException("ORA-03123 The service context was established in nonblocking mode, and the current operation could not be completed immediately.  The operation must be called again to complete.", file, line, 3123);
            
        case OCI_CONTINUE:
            throw new OracleException("This error is returned only from a callback function. It indicates that the callback function wants the OCI library to resume its normal processing.", file, line);
            
        default:
            throw new OracleException("Unknown error return code.", file, line);
    }
}

private auto allocateHandle(THandle)()
{
    static assert(__traits(compiles, handleType!THandle));

    THandle* handle;
    OCIHandleAlloc(
        cast(void*)environment, 
        cast(void**)&handle, 
        handleType!THandle, 
        0, 
        null)
        .checkResult(environment);
    
    return handle;
}

private void freeHandle(THandle)(ref THandle* handle)
{
    static assert (__traits(compiles, handleType!THandle));
    
    OCIHandleFree(handle, handleType!handle).checkResult(environment);
    handle = null;
}

// This is for functions that require an environment or error, but do not 
// require a conncetion and therefore can be used on a different thread 
// to the main Oracle worker thread.
private static OCIEnv* environment;
private static OCIError* error;

public static void ThreadLocalInitialisation()
{
    // This doesn't have a constant declared.
    // https://stackoverflow.com/questions/69139801/how-do-i-use-ocienvnlscreate-to-always-get-char-and-nchar-data-back-in-utf8-en
    enum OCI_UTF8 = 871;

    OCIEnvNlsCreate(
        &environment, 
        OCI_THREADED | OCI_NO_MUTEX | OCI_OBJECT, 
        null, 
        null, 
        null, 
        null, 
        0, 
        null, 
        OCI_UTF8,
        OCI_UTF8)
        .checkResult(environment);
    
    error = allocateHandle!OCIError;
}

public static void ThreadLocalFinalisation()
{
    freeHandle(error);
    freeHandle(environment);
}

public struct OracleNumber
{
    private immutable OCINumber number;
    
    this(ubyte[] data)
    {
        number = immutable OCINumber(data[0 .. OCINumber.sizeof]);
    }
    
    this(double value)
    {
        OCINumberFromReal(
            error, 
            cast(void*)&value, 
            cast(uint)value.sizeof, 
            cast(OCINumber*)&number)
            .checkResult(error);
    }
    
    void free()
    {
        GC.free(GC.addrOf(cast(void*)number.OCINumberPart.ptr));
    }
    
    
    // public auto createNumber(string representation, string format)
    // {
    //     auto buffer = new ubyte[22];
    //     
    //     OCINumberFromText(
    //         error, 
    //         cast(const ubyte*)representation.ptr, 
    //         cast(uint)representation.length, 
    //         cast(const ubyte*)format.ptr, 
    //         cast(uint)format.length, 
    //         null, 
    //         0, 
    //         cast(OCINumber*)buffer.ptr)
    //         .checkResult(error);
    //     
    //     return buffer;
    // }
    
    public auto formatNumber(const string numberFormat) const
    {
        static char[255] textBuffer;
        uint textBufferSize = textBuffer.length;
        
        try
            OCINumberToText(
                error, 
                &number, 
                cast(const ubyte*)numberFormat.ptr, 
                cast(uint)numberFormat.length, 
                null, 
                0, 
                &textBufferSize, 
                cast(ubyte*)textBuffer.ptr)
                .checkResult(error);
        catch (OracleException exception)
        {
            textBufferSize = cast(uint)min(numberFormat.length, 255);
            textBuffer[0 .. textBufferSize] = '#';
        }
        
        return textBuffer[0 .. textBufferSize];
    }
    
    public TInteger to(TInteger)() const 
    if (isIntegral!TInteger)
    {
        TInteger integer;
        
        OCINumberToInt(
            error, 
            &number, 
            integer.sizeof, 
            isSigned!TInteger ? OCI_NUMBER_SIGNED : OCI_NUMBER_UNSIGNED, 
            &integer);
        
        return integer;
    }
    
    public TReal to(TReal)() const
    if (isFloatingPoint!TReal)
    {
        TReal floatingPoint;
        
        OCINumberToReal(
            error, 
            &number, 
            floatingPoint.sizeof, 
            &floatingPoint);
        
        return floatingPoint;
    }
}

public string threadLocalNlsDateFormat;

public OracleDate toOracleDate(SysTime dateTime)
{
    OCIDate oracleDate;
    
    OCIDateSetDate(
        &oracleDate, 
        dateTime.year, 
        dateTime.month, 
        dateTime.day);
    OCIDateSetTime(
        &oracleDate, 
        dateTime.hour, 
        dateTime.minute, 
        dateTime.second);
    
    static char[255] dateAsText;
    uint dateLength = dateAsText.length;
    
    OCIDateToText(
        error, 
        &oracleDate, 
        cast(const(ubyte)*)threadLocalNlsDateFormat, 
        cast(ubyte)threadLocalNlsDateFormat.length, 
        null, 
        cast(ulong)0, 
        &dateLength, 
        cast(ubyte*)dateAsText.ptr)
        .checkResult(error);
    
    return OracleDate(
                dateTime, 
                dateAsText[0 .. dateLength].to!string);                        
}

public abstract final class CrossThreadCancellation
{
    // This only exists so we can cancel the current command from another thread.  
    // This is necessary because the worker thread will be blocked when the command 
    // is being executed server-side.
    // 
    // To achieve this, I cast the connection to shared on assignment, and cast away
    // on use.  I think this is safe because the OCIBreak call is only intended to 
    // be used in a multi-threaded scenario, and the connection is not shared with 
    // anything else (hence the real reference is considered thread local to D).
    
    private static shared OCISvcCtx*[Tid] unsafeContextsByWorker;
    
    private static void SetDetailsFromWorkerThread(OCISvcCtx* serviceContext)
    {
        unsafeContextsByWorker[thisTid] = cast(shared(OCISvcCtx*))serviceContext;
    }
    
    private static void ClearDetailsFromWorkerThread()
    {
        unsafeContextsByWorker.remove(thisTid);
    }
    
    public static bool CancelFromMainThread(Tid workerThreadId)
    {
        auto unsafeContextRef = workerThreadId in unsafeContextsByWorker;
        if (unsafeContextRef is null)
            return false;
        
        OCIBreak(cast(OCISvcCtx*)*unsafeContextRef, error).checkResult(error);
        return true;
    }
}

public final class Worker
{
    public static void Start(Tid ownerThreadId)
    {
        try
        {
            ThreadLocalInitialisation();
            auto worker = new Worker(ownerThreadId);
            scope(exit) worker.Disconnect;
            
            worker.Listen;
        }
        // catch (OwnerFailed) { }
        catch (LinkTerminated) { }
        catch (OwnerTerminated) { }
        catch (Throwable e)
        {
            auto stackTrace = appender!string("Background Oracle thread failure:\r\n\r\n");
            
            foreach(line; e.info)
            {
                stackTrace.put(line);
                stackTrace.put("\r\n");
            }
            
            send(ownerThreadId, thisTid, InstructionResult(MessageResult(MessageResultType.Information, stackTrace.data, false)));     
        }
        finally
            ThreadLocalFinalisation;
    }
    
    Tid ownerThreadId;
    private OCIServer* server;
    private OCISvcCtx* serviceContext;
    private OCISession* session;
    private bool isConnected = false;
    private string databaseName;
    private string currentSchema;
    private bool connectionRequestedSilence = false;
    private bool isBulkDbmsOutputSupported = false;
    private bool isProcedureTypeInDataDictionary = false;
    
    this(Tid ownerThreadId)
    {
        this.ownerThreadId = ownerThreadId;
    }
    
    private void debugLocation(uint lineNumber = __LINE__)()
    {
        debug report("Line Number: " ~ lineNumber.to!string);
    }
    
    private void reply(T)(T result)
    { 
        send(ownerThreadId, thisTid, InstructionResult(result)); 
    }
    
    private void reply(MessageResultType result, string message = "", bool isFormattable = false)
    {
        reply(MessageResult(result, message, isFormattable));
    }
    
    private void report(string message)
    {
        reply(MessageResultType.Information, message);
    }
    
    private void reportWarning(string message)
    {
        reply(MessageResultType.Warning, message);
    }
    
    private void replyThreadFailure(string message)
    {
        prioritySend(ownerThreadId, thisTid, InstructionResult(MessageResult(MessageResultType.ThreadFailure, message, false)));
    }
    
    private void setAttribute(TValue, THandle)(THandle* handle, uint attributeType, TValue value)
        if (__traits(compiles, handleType!THandle) && isIntegral!TValue)
    {
        OCIAttrSet(
            cast(void*)handle, 
            handleType!THandle, 
            cast(void*)&value,
            TValue.sizeof, 
            attributeType, 
            error)
            .checkResult(error, &reportWarning);
    }
    
    private void setAttribute(TValue, THandle)(THandle* handle, uint attributeType, TValue* value)
        if (__traits(compiles, handleType!THandle) && !isIntegral!TValue)
    {
        OCIAttrSet(
            cast(void*)handle, 
            handleType!THandle, 
            cast(void*)value,
            0, 
            attributeType, 
            error)
            .checkResult(error, &reportWarning);
    }
    
    private void setAttributeText(THandle)(THandle* handle, uint attributeType, string text)
        if (__traits(compiles, handleType!THandle))
    {
        OCIAttrSet(
            cast(void*)handle, 
            handleType!THandle, 
            cast(void*)text.ptr,
            cast(uint)text.length, 
            attributeType, 
            error)
            .checkResult(error, &reportWarning);
    }
    
    private auto getAttribute(TReturn, THandle)(THandle* handle, uint attributeType)
        if (__traits(compiles, handleType!THandle) /*&& isIntegral!TReturn*/)
    {
        TReturn result;
        OCIAttrGet(
            cast(const(void)*)handle, 
            handleType!THandle, 
            cast(void*)&result,
            null, 
            attributeType, 
            error)
            .checkResult(error, &reportWarning);
        
        return result;
    }
    
    private auto getAttributeText(THandle)(THandle* handle, uint attributeType)
        if (__traits(compiles, handleType!THandle))
    {
        static char* textLocation;
        uint size;
        
        OCIAttrGet(
            cast(const(void)*)handle, 
            handleType!THandle, 
            cast(void**)&textLocation,
            &size, 
            attributeType, 
            error)
            .checkResult(error, &reportWarning);
        
        return textLocation[0 .. size].dup;
    }
    
    void Connect(const ConnectionDetails details)
    {
        connectionRequestedSilence = details.isSilent;
    
        scope(success) isConnected = true;
        
        try
        {
            uint connectionType;
            
            final switch (details.type) with (ConnectionDetails.Types)
            {
                case Normal:  connectionType = OCI_DEFAULT;  break;
                case SysDba:  connectionType = OCI_SYSDBA;   break;
                case SysOper: connectionType = OCI_SYSOPER;  break;
            }
            
            if (serviceContext !is null && session !is null)
            {
                OCISessionEnd(serviceContext, error, session, OCI_DEFAULT).checkResult(error, &reportWarning);
                freeHandle(session);
            }
            
            if (server !is null)
            {
                OCIServerDetach(server, error, OCI_DEFAULT).checkResult(error, &reportWarning);
                freeHandle(server);
            }
            
            if (serviceContext !is null)
            {
                freeHandle(serviceContext);
            }
            
            server = allocateHandle!OCIServer;
            scope (failure) freeHandle(server);
            
            // Create a server context
            OCIServerAttach(
                server, 
                error, 
                cast(const(ubyte)*)details.host.ptr, 
                cast(uint)details.host.length, 
                OCI_DEFAULT)
                .checkResult(error, &reportWarning);
            
            scope (failure) OCIServerDetach(server, error, OCI_DEFAULT).checkResult(error, &reportWarning);
            
            // TODO: Experiment with: setAttribute(server, OCI_ATTR_NONBLOCKING_MODE, 1);
            
            serviceContext = allocateHandle!OCISvcCtx;
            scope (failure) freeHandle(serviceContext);
            
            setAttribute(serviceContext, OCI_ATTR_SERVER, server);
            
            // // set the server attribute in the service handle
            // OCIAttrSet(cast(void*)serviceContext, handleType!serviceContext, cast(void*)server, 0, OCI_ATTR_SERVER, error).checkResult(error, &reportWarning);
            
            session = allocateHandle!OCISession;
            scope (failure) freeHandle(session);
            
            if (details.newPassword.length > 0)
            {
                setAttribute(serviceContext, OCI_ATTR_SESSION, session);
                
                setAttributeText(session, OCI_ATTR_USERNAME, details.username);
                setAttributeText(session, OCI_ATTR_PASSWORD, details.password);
                
                OCIPasswordChange(
                    serviceContext, 
                    error, 
                    cast(const(ubyte)*)details.username.ptr, 
                    cast(uint)details.username.length, 
                    cast(const(ubyte)*)details.password.ptr, 
                    cast(uint)details.password.length, 
                    cast(const(ubyte)*)details.newPassword.ptr, 
                    cast(uint)details.newPassword.length, 
                    OCI_AUTH)
                    .checkResult(error, &reportWarning);
                
                session = getAttribute!(OCISession*)(
                    serviceContext, 
                    OCI_ATTR_SESSION);
                
                report("Password changed.");
            }
            else
            {
                setAttributeText(session, OCI_ATTR_USERNAME, details.username);
                setAttributeText(session, OCI_ATTR_PASSWORD, details.password);
                
                OCISessionBegin(
                    serviceContext, 
                    error, 
                    session, 
                    OCI_CRED_RDBMS, 
                    connectionType)
                    .checkResult(error, &reportWarning);
                
                scope (failure) OCISessionEnd(serviceContext, error, session, OCI_DEFAULT).checkResult(error, &reportWarning);
                
                // set the user session attribute in the service context handle
                setAttribute(serviceContext, OCI_ATTR_SESSION, session);
                
                // OCILogon(
                //     environment, 
                //     error, 
                //     &serviceContext, 
                //     cast(const(ubyte)*)details.username.ptr, 
                //     cast(uint)details.username.length, 
                //     cast(const(ubyte)*)details.password.ptr, 
                //     cast(uint)details.password.length, 
                //     cast(const(ubyte)*)details.host.ptr, 
                //     cast(uint)details.host.length)
                //     .checkResult(error, &reportWarning);
            }
        }
        catch (RecoverableException exception)
        {
            reply(MessageResultType.Disconnected, "Connection Failed" ~ lineEnding);
            throw exception;
        }
        
        CrossThreadCancellation.SetDetailsFromWorkerThread(serviceContext);
        
        isBulkDbmsOutputSupported = ExecuteScalarSynchronous(
            "SELECT '1' FROM all_objects WHERE owner = 'SYS' AND object_name = 'DBMSOUTPUT_LINESARRAY'")
            == "1";
        
        isProcedureTypeInDataDictionary = ExecuteScalarSynchronous(
            "SELECT '1' FROM all_tab_columns WHERE owner = 'SYS' AND table_name = 'ALL_PROCEDURES' AND column_name = 'OBJECT_TYPE'")
            == "1";
        
        databaseName = ExecuteScalarSynchronous(
            "SELECT SYS_CONTEXT('USERENV', 'DB_NAME') FROM dual");
        
        currentSchema = ExecuteScalarSynchronous(
            "SELECT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') FROM dual");
        
        SendStatus;
        
        if (!connectionRequestedSilence)
        {
            const databaseBanner = ExecuteScalarSynchronous(
                "SELECT banner FROM v$version WHERE banner LIKE 'Oracle Database%' AND ROWNUM = 1");
            
            report("Connected to " ~ currentSchema ~ "@" ~ databaseName);
            report(databaseBanner);
        }
        
        ExecuteScalarSynchronous(
            "ALTER SESSION SET                                                  \n" ~ 
            "     NLS_DATE_FORMAT = 'DD-Mon-YYYY HH24:MI:SS'                    \n" ~ 
            "     NLS_TIMESTAMP_FORMAT = 'DD-Mon-YYYY HH24:MI:SS FF'            \n" ~ 
            "     NLS_TIMESTAMP_TZ_FORMAT = 'DD-Mon-YYYY HH24:MI:SS FF TZH:TZM' \n");
        
        RefreshDefaultDateFormat;
        
        ExecuteScalarSynchronous("BEGIN DBMS_OUTPUT.ENABLE(1000000); END;");
        
        // static char[OCI_NLS_MAXBUFSZ] nlsCharacterSet;
        // OCINlsGetInfo(
        //     cast(void*)session, 
        //     error, 
        //     cast(ubyte*)nlsCharacterSet.ptr, 
        //     nlsCharacterSet.length, 
        //     cast(ushort)OCI_NLS_CHARACTER_SET)
        //     .checkResult(error, &reportWarning);
        // 
        // report("Character set = \"" ~ nlsCharacterSet.ptr.FromCString ~ "\"");
        
        reply(MessageResultType.Connected, currentSchema ~ "@" ~ databaseName);
    }
    
    void Disconnect() 
    {
        scope(success) isConnected = false;
        
        if (session !is null)
        {
            OCISessionEnd(serviceContext, error, session, OCI_DEFAULT).checkResult(error, &reportWarning);
            freeHandle(session);
        }
        
        if (server !is null)
        {
            OCIServerDetach(server, error, OCI_DEFAULT).checkResult(error, &reportWarning);
            freeHandle(server);
        }
        
        if (serviceContext !is null)
        {
            freeHandle(serviceContext);
        }
        
        CrossThreadCancellation.ClearDetailsFromWorkerThread;
        reply(MessageResultType.Disconnected, "Disconnected" ~ lineEnding);
    }
    
    void SendStatus() => 
        reply(StatusFlags(
            (isBulkDbmsOutputSupported       ? StatusFlag.isBulkDbmsOutputSupported       : StatusFlag.None) | 
            (isProcedureTypeInDataDictionary ? StatusFlag.isProcedureTypeInDataDictionary : StatusFlag.None)));
    
    void Listen()
    {
        while (true)
        {
            try
            {
                // Apparently using send inside receive causes a deadlock, 
                // so store the data locally and keep receive short.
                Instruction instruction;
                
                receive
                (
                    (Tid senderThreadId, Instruction innerInstruction)
                    {
                        if (senderThreadId != ownerThreadId)
                            throw new RecoverableException("Oracle Worker Thread received unexpected message from " ~ senderThreadId.to!string ~ ".");
                        
                        instruction = innerInstruction;
                    }, 
                    
                    (Variant unknownMessage)
                    {
                        throw new RecoverableException("Oracle Worker Thread received unexpected message of type " ~ unknownMessage.type.toString ~ ".");
                    }
                );
                
                instruction.match!(
                    (ConnectionDetails     connectionDetails) => Connect(connectionDetails), 
                    (ExecuteInstruction    instruction)       => Execute(instruction.Command, instruction.LineNumber, instruction.IsSilent), 
                    (ObjectInstruction     instruction)
                    {
                        final switch (instruction.type)
                        {
                            case ObjectInstruction.Types.Describe:   return Describe(instruction.name, instruction.type);
                            case ObjectInstruction.Types.ShowSource: return Describe(instruction.name, instruction.type);
                            case ObjectInstruction.Types.ShowErrors: return ShowErrors(instruction.name, instruction.variant);
                        }
                    }, 
                    (SimpleInstruction instruction)
                    {
                        final switch (instruction)
                        {
                            case instruction.Disconnect: return Disconnect;
                            case instruction.Cancel:     return; // Ignore cancellations received at this point.
                            case instruction.Kill:       throw new WorkerKilledException;
                        }
                    }
                );
            }
            catch (WorkerKilledException)
            {
                return;
            }
            catch (InstructionCancelledException)
            {
                reply(MessageResultType.Cancelled);
            }
            catch (OracleException exception)
            {
                if (exception.code == 28001)
                    reply(MessageResultType.PasswordExpired);
                else
                    reply(MessageResultType.Failure, exception.msg ~ lineEnding);
            }
            catch (RecoverableException exception)
            {
                reply(MessageResultType.Failure, exception.msg ~ lineEnding);
            }
            catch (Throwable exception)
            {
                replyThreadFailure(
                    exception.msg ~ lineEnding ~ lineEnding ~ "\tLine: " ~ 
                    exception.line.to!string ~ lineEnding ~ lineEnding ~ 
                    exception.info.toString);
                throw exception;
            }
        }
    }
    
    private string nlsDateFormat;
    private string nlsTimestampFormat;
    private string nlsTimestampTimezoneFormat;
    
    void RefreshDefaultDateFormat()
    {
        alias Result = Tuple!(string, "name", string, "format");
        
        foreach (result; ExecuteSynchronous!Result(
            "SELECT parameter     AS name,  \n" ~ 
            "       value         AS format \n" ~ 
            "  FROM nls_session_parameters  \n" ~ 
            " WHERE parameter IN            \n" ~ 
            "   (                           \n" ~ 
            "   'NLS_DATE_FORMAT',          \n" ~ 
            "   'NLS_TIMESTAMP_FORMAT',     \n" ~ 
            "   'NLS_TIMESTAMP_TZ_FORMAT'   \n" ~ 
            "   )                           \n"))
        {
            switch (result.name)
            {
                case "NLS_DATE_FORMAT"         : nlsDateFormat              = result.format; reply(MessageResultType.NlsDateFormat, result.format); break;
                case "NLS_TIMESTAMP_FORMAT"    : nlsTimestampFormat         = result.format; break;
                case "NLS_TIMESTAMP_TZ_FORMAT" : nlsTimestampTimezoneFormat = result.format; break;
                default: break;
            }
        }
    }
    
    OracleObjectName LookupSynonym(const OracleObjectName source)
    {
        auto atDatabaseLink = source.DatabaseLinkName.length == 0 ? "" : "@" ~ source.DatabaseLinkName;
        
        auto synonymSql = 
            "SELECT table_owner,                      \n" ~ 
            "       table_name,                       \n" ~ 
            "       db_link                           \n" ~ 
            "  FROM all_synonyms" ~ atDatabaseLink ~ "\n" ~ 
            " WHERE owner = NVL(:p_schema, owner)     \n" ~ 
            "   AND synonym_name = :p_object_name     \n";
        
        // We cannot allow a double hop because other queries 
        // and things do not allow it.
        if (source.DatabaseLinkName.length > 0)
            synonymSql ~= 
            "   AND db_link IS NULL\n";
        
        synonymSql ~= 
            " ORDER BY DECODE(owner, 'PUBLIC', 1, 2)\n";
        
        alias Result = Tuple!(string, "Schema", string, "ObjectName", string, "DatabaseLinkName");
        
        auto synonyms = ExecuteSynchronous!Result
           (synonymSql, 
            createInputBinding("p_schema", source.Schema), 
            createInputBinding("p_object_name", source.ObjectName));
        
        if (synonyms.length == 0)
            return source;
        
        if (source.DatabaseLinkName.length == 0)
        return OracleObjectName(
            synonyms[0].Schema, 
            synonyms[0].ObjectName, 
            null, 
            synonyms[0].DatabaseLinkName);
        
        return OracleObjectName(
            synonyms[0].Schema, 
            synonyms[0].ObjectName, 
            null, 
            source.DatabaseLinkName);
    }
    
    
    void Describe(const OracleObjectName source, const ObjectInstruction.Types instructionType)
    {
        if (!isConnected)
            throw new RecoverableException("No database connection.");    
        
        string GetDatabaseLinkWithAt(const OracleObjectName name)
        {
            return name.DatabaseLinkName.length == 0 ? "" : "@" ~ name.DatabaseLinkName;
        }
        
        OracleObjectName name = source;
        auto atDatabaseLink = GetDatabaseLinkWithAt(name);
        
        string GetObjectType(const OracleObjectName name)
        {
            auto objectTypeSql = 
                "SELECT object_type                      \n" ~ 
                "  FROM all_objects" ~ atDatabaseLink ~ "\n" ~ 
                " WHERE owner = NVL(:p_schema, owner)    \n" ~ 
                "   AND object_name = :p_object_name     \n" ~ 
                "   AND object_type != 'SYNONYM'         \n" ~ 
                "   AND (    :p_schema IS NOT NULL       \n" ~ 
                "         OR owner = 'PUBLIC'            \n" ~ 
                "         OR owner = :p_current_schema) \n";
            return ExecuteScalarSynchronous(objectTypeSql, 
                createInputBinding("p_schema", name.Schema), 
                createInputBinding("p_object_name", name.ObjectName), 
                createInputBinding("p_current_schema", currentSchema));
        }
        
        auto objectType = GetObjectType(name);
        if (objectType.length == 0)
        {
            name = LookupSynonym(name);
            atDatabaseLink = GetDatabaseLinkWithAt(name);
            objectType = GetObjectType(name);
            
            if (objectType.length == 0)
            {
                reply(MessageResultType.Failure, "Object not found." ~ lineEnding);
                return;
            }
        }
        
        // Probably not worth adding descriptions for these:
        //     Count OBJECT_TYPE       
        //     ~~~~~ ~~~~~~~~~~~~~~~~~~
        //     1     EDITION           
        //     2     CONSUMER GROUP    
        //     3     SCHEDULE          
        //     45    OPERATOR          
        //     2     DESTINATION       
        //     9     WINDOW            
        //     4     SCHEDULER GROUP   
        //     11    PROGRAM           
        //     2     LOB               
        //     31    XML SCHEMA        
        //     2     JOB CLASS         
        //     3976  SYNONYM           
        //     8     INDEXTYPE         
        //     1     EVALUATION CONTEXT
        
        if (instructionType == ObjectInstruction.Types.Describe)
        {
            switch (objectType)
            {
                case "TABLE", "VIEW":
                    
                    auto describeTableSql =
                        "SELECT column_name                                              AS \"Name\",           \n" ~ 
                        "       DECODE(nullable, 'N', 'NOT NULL', ' ')                   AS \"Null?\",          \n" ~ 
                        "       CASE                                                                            \n" ~ 
                        "            WHEN data_type = 'NUMBER' THEN                                             \n" ~ 
                        "                data_type || '(' ||                                                    \n" ~ 
                        "                NVL2(data_precision, TO_CHAR(data_precision), TO_CHAR(data_length)) || \n" ~ 
                        "                NVL2(data_scale, ', ' || TO_CHAR(data_scale), '') || ')'               \n" ~ 
                        "            WHEN data_type IN ('CHAR', 'VARCHAR', 'VARCHAR2') THEN                     \n" ~ 
                        "                data_type || '(' ||                                                    \n" ~ 
                        "                TO_CHAR(data_length) || ')'                                            \n" ~ 
                        "            ELSE data_type                                                             \n" ~ 
                        "       END                                                      AS \"Type\",           \n" ~ 
                        "       data_default                                             AS \"Default\",        \n" ~ 
                        "       comments                                                 AS \"Comments\"        \n" ~ 
                        "  FROM all_tab_columns" ~ atDatabaseLink ~ "                                           \n" ~ 
                        "  LEFT JOIN all_col_comments" ~ atDatabaseLink ~ "                                     \n" ~ 
                        "  USING (owner, table_name, column_name)                                               \n" ~ 
                        " WHERE owner = NVL(:p_schema, owner)                                                   \n" ~ 
                        "   AND table_name = :p_table_name                                                      \n" ~ 
                        "   AND (    :p_schema IS NOT NULL                                                      \n" ~ 
                        "         OR owner = 'PUBLIC'                                                           \n" ~ 
                        "         OR owner = :p_current_schema)                          \n" ~ 
                        " ORDER BY column_id ASC                                                                \n";
                    
                    Execute(describeTableSql, 0, false, 
                        createInputBinding("p_schema", name.Schema), 
                        createInputBinding("p_table_name", name.ObjectName), 
                        createInputBinding("p_current_schema", currentSchema));
                    return;
                    
                case "SEQUENCE":
                    
                    auto describeSequenceSql =
                        "WITH sequence_record AS                                                                                    \n" ~ 
                        "(                                                                                                          \n" ~ 
                        "    SELECT sequence_owner,                                                                                 \n" ~ 
                        "           sequence_name,                                                                                  \n" ~ 
                        "           min_value,                                                                                      \n" ~ 
                        "           max_value,                                                                                      \n" ~ 
                        "           increment_by,                                                                                   \n" ~ 
                        "           cycle_flag,                                                                                     \n" ~ 
                        "           order_flag,                                                                                     \n" ~ 
                        "           cache_size,                                                                                     \n" ~ 
                        "           last_number                                                                                     \n" ~ 
                        "      FROM all_sequences" ~ atDatabaseLink ~ "                                                             \n" ~ 
                        "     WHERE sequence_owner = NVL(:p_schema, sequence_owner)                                                 \n" ~ 
                        "       AND sequence_name = :p_sequence_name                                                                \n" ~ 
                        "       AND (    :p_schema IS NOT NULL                                                                      \n" ~ 
                        "             OR sequence_owner = 'PUBLIC'                                                                  \n" ~ 
                        "             OR sequence_owner = :p_current_schema)                                                           \n" ~ 
                        ")                                                                                                          \n" ~ 
                        "SELECT 'Sequence Owner' AS \"Property\", sequence_owner        AS \"Value\" FROM sequence_record UNION ALL \n" ~ 
                        "SELECT 'Sequence Name'  AS \"Property\", sequence_name         AS \"Value\" FROM sequence_record UNION ALL \n" ~ 
                        "SELECT 'Min Value'      AS \"Property\", TO_CHAR(min_value)    AS \"Value\" FROM sequence_record UNION ALL \n" ~ 
                        "SELECT 'Max Value'      AS \"Property\", TO_CHAR(max_value)    AS \"Value\" FROM sequence_record UNION ALL \n" ~ 
                        "SELECT 'Increment By'   AS \"Property\", TO_CHAR(increment_by) AS \"Value\" FROM sequence_record UNION ALL \n" ~ 
                        "SELECT 'Cycle Flag'     AS \"Property\", cycle_flag            AS \"Value\" FROM sequence_record UNION ALL \n" ~ 
                        "SELECT 'Order Flag'     AS \"Property\", order_flag            AS \"Value\" FROM sequence_record UNION ALL \n" ~ 
                        "SELECT 'Cache Size'     AS \"Property\", TO_CHAR(cache_size)   AS \"Value\" FROM sequence_record UNION ALL \n" ~ 
                        "SELECT 'Last Number'    AS \"Property\", TO_CHAR(last_number)  AS \"Value\" FROM sequence_record           \n";
                    
                    Execute(describeSequenceSql, 0, false, 
                        createInputBinding("p_schema", name.Schema), 
                        createInputBinding("p_sequence_name", name.ObjectName), 
                        createInputBinding("p_current_schema", currentSchema));
                    return;
                
                case "PACKAGE", "PROCEDURE", "FUNCTION":
                    
                    auto stopWatch = StopWatch(AutoStart.yes);
                    
                    auto describeProcedureSql = 
                        "SELECT owner,                              \n" ~ 
                        "       object_name,                        \n" ~ 
                        "       procedure_name,                     \n" ~ 
                        "       " ~ (isProcedureTypeInDataDictionary ? "object_type" : "''") ~ ", \n" ~ 
                        "       overload                            \n" ~ 
                        "  FROM all_procedures" ~ atDatabaseLink ~ "\n" ~ 
                        " WHERE owner = NVL(:p_schema, owner)       \n" ~ 
                        "   AND object_name = :p_object_name        \n" ~ 
                        "   AND (    :p_schema IS NOT NULL                             \n" ~ 
                        "         OR owner = 'PUBLIC'                                  \n" ~ 
                        "         OR owner = :p_current_schema) \n" ~ 
                        " ORDER BY subprogram_id                    \n";
                    
                    alias ProcedureResult = Tuple!(string, "Schema", string, "ObjectName", string, "ProcedureName", string, "Type", string, "Overload");
                    
                    auto procedures = ExecuteSynchronous!ProcedureResult(
                        describeProcedureSql, 
                        createInputBinding("p_schema",      name.Schema), 
                        createInputBinding("p_object_name", name.ObjectName), 
                        createInputBinding("p_current_schema", currentSchema));
                    
                    auto description = appender!string;
                    auto firstMember = true;
                    
                    foreach (procedure; procedures)
                    {
                        CheckCancellationRequested;
                    
                        if (procedure.Type == "PACKAGE" && procedure.ProcedureName.length == 0)
                        {
                            description.put("PACKAGE ");
                            description.put(procedure.Schema);
                            description.put(".");
                            description.put(procedure.ObjectName);
                            description.put(lineEnding ~ lineEnding);
                            
                            // Try and get package level variables if possible.  I think this view 
                            // isn't usually populated or granted, but make an effort anyway.
                            
                            auto describeVariablesSql = 
                                "SELECT name, data_type                           \n" ~ 
                                "  FROM                                           \n" ~ 
                                "    (                                            \n" ~ 
                                "    SELECT name,                                 \n" ~ 
                                "           line,                                 \n" ~ 
                                "           usage_id,                             \n" ~ 
                                "           usage,                                \n" ~ 
                                "           LEAD(name)                            \n" ~ 
                                "               OVER (ORDER BY line, usage_id)    \n" ~ 
                                "               AS data_type,                     \n" ~ 
                                "           LEAD(usage_context_id)                \n" ~ 
                                "               OVER (ORDER BY line, usage_id)    \n" ~ 
                                "               AS type_usage_context_id,         \n" ~ 
                                "           LEAD(usage)                           \n" ~ 
                                "               OVER (ORDER BY line, usage_id)    \n" ~ 
                                "               AS type_usage                     \n" ~ 
                                "      FROM all_identifiers                       \n" ~
                                "     WHERE owner = NVL(:p_schema, owner)         \n" ~      
                                "       AND object_name      = :p_object_name     \n" ~ 
                                "       AND object_type      = 'PACKAGE'          \n" ~      
                                "       AND type            != 'PACKAGE'          \n" ~      
                                "       AND usage IN ('DECLARATION', 'REFERENCE') \n" ~ 
                                "    )                                            \n" ~ 
                                " WHERE type_usage_context_id = usage_id          \n" ~ 
                                "   AND usage = 'DECLARATION'                     \n" ~ 
                                "   AND type_usage = 'REFERENCE'                  \n" ~ 
                                " ORDER BY line, usage_id                         \n";
                            
                            alias VariableResult = Tuple!(string, "Name", string, "DataType");
                            
                            try
                            {
                                auto variables = ExecuteSynchronous!VariableResult(
                                    describeVariablesSql, 
                                    createInputBinding("p_schema",      procedure.Schema), 
                                    createInputBinding("p_object_name", procedure.ObjectName));
                                
                                auto maximumVariableNameLength = variables.map!(v => v.Name.toUtf8Slice.intLength).reduceMax(0);
                                
                                foreach (variable; variables)
                                {
                                    description.put("    ");
                                    description.put(variable.Name.leftJustify(maximumVariableNameLength));
                                    description.put(" ");
                                    description.put(variable.DataType);
                                    description.put(";");
                                    description.put(lineEnding);
                                }
                                
                                if (variables.length > 0)
                                    description.put(lineEnding);
                            }
                            catch (OracleException exception)
                            {
                                if (exception.code != 942) // ORA-00942: table or view does not exist.
                                    throw exception;
                            }
                            
                            continue;
                        }
                        
                        auto describeParametersSql = 
                            "SELECT argument_name,                                          \n" ~ 
                            "       NVL(pls_type, data_type) AS type,                       \n" ~ 
                            "       in_out,                                                 \n" ~ 
                            "       CASE                                                    \n" ~ 
                            "           WHEN char_used = 'C'                                \n" ~ 
                            "           THEN char_length                                    \n" ~ 
                            "           ELSE data_length                                    \n" ~ 
                            "       END AS data_length,                                     \n" ~ 
                            "       data_precision,                                         \n" ~ 
                            "       data_scale,                                             \n" ~ 
                            "       char_used,                                              \n" ~ 
                            "       data_level,                                             \n" ~ 
                            "       type_owner,                                             \n" ~ 
                            "       type_name,                                              \n" ~ 
                            "       type_subname,                                           \n" ~ 
                            "       " ~ (DefaultedFieldExists(atDatabaseLink) ? "" : "'N' AS ") ~ 
                                    "defaulted                                              \n" ~ 
                            "  FROM all_arguments" ~ atDatabaseLink ~ "                     \n" ~ 
                            " WHERE owner = :p_schema                                       \n" ~ 
                            "   AND object_name = :p_object_name                            \n" ~ 
                            "   AND NVL(package_name, 'NULL') = NVL(:p_package_name, 'NULL')\n" ~ 
                            "   AND NVL(overload,     'NULL') = NVL(:p_overload, 'NULL')    \n" ~ 
                            " ORDER BY overload,                                            \n" ~ 
                            "          position,                                            \n" ~ 
                            "          data_level                                           \n";
                        
                        alias ParameterResult = Tuple!(
                            string,        "ArgumentName", 
                            string,        "Type", 
                            string,        "InOut", 
                            Nullable!long, "Length", 
                            Nullable!long, "Precision", 
                            Nullable!long, "Scale", 
                            string,        "CharUsedBOrC", 
                            long,          "DataLevel", 
                            string,        "TypeOwner", 
                            string,        "TypeName", 
                            string,        "TypeSubName", 
                            string,        "IsDefaultedYN");
                        
                        auto subObjectName = 
                            procedure.Type == "PACKAGE" ? 
                            procedure.ProcedureName : 
                            name.ObjectName;
                        
                        auto packageObjectName = 
                            procedure.Type == "PACKAGE" ? 
                                name.ObjectName : 
                                "";
                        
                        auto parameters = ExecuteSynchronous!ParameterResult(
                            describeParametersSql, 
                            createInputBinding("p_schema",       procedure.Schema), 
                            createInputBinding("p_object_name",  subObjectName), 
                            createInputBinding("p_package_name", packageObjectName), 
                            createInputBinding("p_overload",     procedure.Overload));
                        
                        string indentation;
                        
                        auto maximumParameterNameLength = parameters.map!(p => p.ArgumentName.toUtf8Slice.intLength).reduceMax(0);
                        auto maximumParameterInOutLength = parameters.map!(p => p.InOut.toUtf8Slice.intLength).reduceMax(0);
                        
                        if (firstMember)
                            firstMember = false;
                        else
                            description.put(lineEnding);
                        
                        if (procedure.Type == "PACKAGE")
                        {
                            description.put("    ");
                            
                            // The first parameter is the function return type if there is no name.
                            if (parameters.length > 0 && parameters[0].ArgumentName.length == 0 && parameters[0].Type.length > 0)
                                description.put("FUNCTION");
                            else
                                description.put("PROCEDURE");
                            
                            description.put(" ");
                            description.put(procedure.ProcedureName);
                            indentation = "        ";
                        }
                        else
                        {
                            description.put(procedure.Type);
                            description.put(" ");
                            description.put(procedure.Schema);
                            description.put(".");
                            description.put(procedure.ObjectName);
                            indentation = "    ";
                        }
                        
                        void AppendType(bool isInReturnPosition)(ParameterResult parameter)
                        {
                            if (parameters.any!(otherParameter =>
                                    otherParameter.ArgumentName == parameter.ArgumentName && 
                                    otherParameter.DataLevel != parameter.DataLevel))
                            {
                                description.put(lineEnding);
                                description.put(indentation);
                                foreach (_; ((parameter.DataLevel + 1) * 4).iota)
                                    description.put(" ");
                            }
                            else
                                description.put(" ");
                            
                            static if (!isInReturnPosition)
                            {
                                description.put(parameter.InOut.rightJustify(maximumParameterInOutLength));
                                description.put(" ");
                            }
                            
                            description.put(parameter.Type);
                            
                            if ((parameter.Type == "VARCHAR2" || 
                                 parameter.Type == "NVARCHAR2" || 
                                 parameter.Type == "CHAR" || 
                                 parameter.Type == "NCHAR") && 
                                     !parameter.Length.isNull)
                            {
                                description.put("(");
                                description.put(parameter.Length.to!string);
                                
                                if (parameter.CharUsedBOrC == "B")
                                    description.put(" BYTE");
                                else if (parameter.CharUsedBOrC == "C")
                                    description.put(" CHAR");
                                
                                description.put(")");
                            }
                            else if (!parameter.Precision.isNull)
                            {
                                description.put("(");
                                description.put(parameter.Precision.get.to!string);
                                
                                if (!parameter.Scale.isNull)
                                {
                                    description.put(", ");
                                    description.put(parameter.Scale.get.to!string);
                                }
                                
                                description.put(")");
                            }
                            
                            if (parameter.TypeName.length > 0)
                            {
                                description.put(" ");
                            
                                if (parameter.TypeOwner.length > 0)
                                {
                                    description.put(parameter.TypeOwner);
                                    description.put(".");
                                }
                                
                                description.put(parameter.TypeName);
                                
                                if (parameter.TypeSubName.length > 0)
                                {
                                    description.put(" ");
                                    description.put(parameter.TypeSubName);
                                }
                            }
                            
                            if (parameter.IsDefaultedYN == "Y")
                                description.put(" := DEFAULT");
                            
                            foreach (otherParameter; parameters)
                                if (otherParameter.ArgumentName == parameter.ArgumentName && 
                                    otherParameter.DataLevel == parameter.DataLevel + 1)
                                {
                                    AppendType!isInReturnPosition(otherParameter);
                                }
                        }
                        
                        description.put("(");
                        
                        bool firstParameter = true;
                        foreach (parameter; parameters)
                        {
                            if (parameter.ArgumentName.length == 0)
                                continue;
                            
                            if (parameter.DataLevel > 0)
                                continue;
                            
                            if (firstParameter)
                                firstParameter = false;
                            else
                                description.put(",");
                            
                            description.put(lineEnding);
                            description.put(indentation);
                            description.put(parameter.ArgumentName.leftJustify(maximumParameterNameLength));
                            AppendType!false(parameter);
                        }
                        
                        description.put(")");
                        
                        if (procedure.Type != "PROCEDURE")
                            foreach (parameter; parameters)
                            {
                                if (parameter.ArgumentName.length > 0)
                                    continue;
                                
                                if (parameter.DataLevel > 0)
                                    continue;
                                
                                if (parameter.Type.length == 0)
                                    continue;
                                
                                description.put(lineEnding);
                                description.put(indentation);
                                description.put("RETURN");
                                AppendType!true(parameter);
                                break;
                            }
                        
                        description.put(";" ~ lineEnding);
                    }
                    
                    stopWatch.stop;
                    
                    reply(MessageResultType.Information, description.data, true);
                    reply(SqlSuccess(0, false, CommitState.Uncommitted, "", stopWatch.peek, true));
                    return;
                    
                case "INDEX":
                    
                    auto describeIndexSql = 
                        "SELECT c.column_position       AS \"Column Position\",  \n" ~ 
                        "       c.column_name           AS \"Column Name\",      \n" ~ 
                        "       i.uniqueness            AS \"Unique\",           \n" ~ 
                        "       e.column_expression     AS \"Expression\"        \n" ~ 
                        "  FROM all_indexes" ~ atDatabaseLink ~ " i              \n" ~ 
                        "  LEFT JOIN all_ind_columns"  ~ atDatabaseLink ~ " c    \n" ~ 
                        "    ON c.table_owner = i.table_owner                    \n" ~ 
                        "   AND c.index_name  = i.index_name                     \n" ~ 
                        "  LEFT JOIN all_ind_expressions" ~ atDatabaseLink ~ " e \n" ~ 
                        "    ON e.index_name = c.index_name                      \n" ~ 
                        "   AND e.table_name = c.table_name                      \n" ~ 
                        "   AND e.column_position = c.column_position            \n" ~ 
                        " WHERE i.table_owner = NVL(:p_schema, i.table_owner)    \n" ~ 
                        "   AND i.index_name = :p_index_name                     \n" ~ 
                        " ORDER BY                                               \n" ~ 
                        "       c.index_name,                                    \n" ~ 
                        "       c.column_position                                \n";
                    
                    Execute(describeIndexSql, 0, false, createInputBinding("p_schema", name.Schema), createInputBinding("p_index_name", name.ObjectName));
                    return;
                    
                case "TYPE":
                    
                    auto stopWatch = StopWatch(AutoStart.yes);
                    
                    auto describeTypeSql = 
                        "SELECT owner,                          \n" ~ 
                        "       type_name,                      \n" ~ 
                        "       typecode                        \n" ~ 
                        "  FROM all_types                       \n" ~ 
                        " WHERE owner = NVL(:p_schema, owner)   \n" ~ 
                        "   AND type_name = :p_type_name        \n" ~ 
                        "   AND (    :p_schema IS NOT NULL      \n" ~ 
                        "         OR owner = 'PUBLIC'           \n" ~ 
                        "         OR owner = :p_current_schema) \n";
                    
                    alias TypeResult = Tuple!(string, "Schema", string, "ObjectName", string, "TypeCode");
                    
                    auto types = ExecuteSynchronous!TypeResult(
                        describeTypeSql, 
                        createInputBinding("p_schema", name.Schema), 
                        createInputBinding("p_type_name", name.ObjectName), 
                        createInputBinding("p_current_schema", currentSchema));
                    
                    auto description = appender!string;
                    auto firstMember = true;
                    
                    foreach (type; types)
                    {
                        description.put("TYPE ");
                        
                        if (type.Schema.length > 0)
                        {
                            description.put(type.Schema);
                            description.put(".");
                        }
                        
                        if (type.ObjectName.length > 0)
                        {
                            description.put(type.ObjectName);
                            description.put(" ");
                        }
                        
                        description.put(type.TypeCode);
                        description.put(lineEnding);
                        description.put(lineEnding);
                        
                        auto describeTypeAttributesSql = 
                            "SELECT attr_name,                \n" ~ 
                            "       attr_type_mod,            \n" ~ 
                            "       attr_type_owner,          \n" ~ 
                            "       attr_type_name,           \n" ~ 
                            "       length,                   \n" ~ 
                            "       precision,                \n" ~ 
                            "       scale,                    \n" ~ 
                            "       character_set_name,       \n" ~ 
                            "       inherited,                \n" ~ 
                            "       char_used                 \n" ~ 
                            "  FROM all_type_attrs            \n" ~ 
                            " WHERE owner = :p_schema         \n" ~ 
                            "   AND type_name = :p_type_name  \n" ~ 
                            " ORDER BY attr_no ASC            \n";
                        
                        alias AttributeResult = Tuple!(
                            string,        "AttributeName", 
                            string,        "TypeModifier", 
                            string,        "TypeOwner", 
                            string,        "TypeName", 
                            Nullable!long, "Length", 
                            Nullable!long, "Precision", 
                            Nullable!long, "Scale", 
                            string,        "CharacterSetName", 
                            string,        "Inherited", 
                            string,        "CharUsedBOrC");
                        
                        auto attributes = ExecuteSynchronous!AttributeResult(
                            describeTypeAttributesSql, 
                            createInputBinding("p_schema", type.Schema), 
                            createInputBinding("p_type_name", type.ObjectName));
                        
                        auto maximumAttributeNameLength = attributes.map!(a => a.AttributeName.toUtf8Slice.intLength).reduceMax(0);
                        
                        foreach (attribute; attributes)
                        {
                            description.put("    ");
                            description.put(attribute.AttributeName.leftJustify(maximumAttributeNameLength));
                            description.put(" ");
                            
                            if (attribute.TypeModifier.length > 0)
                            {
                                description.put(attribute.TypeModifier);
                                description.put(" ");
                            }
                            
                            if (attribute.TypeOwner.length > 0)
                            {
                                description.put(attribute.TypeOwner);
                                description.put(".");
                            }
                            
                            description.put(attribute.TypeName);
                            
                            if ((attribute.TypeName == "VARCHAR2" || 
                                 attribute.TypeName == "NVARCHAR2" || 
                                 attribute.TypeName == "CHAR" || 
                                 attribute.TypeName == "NCHAR") && 
                                     !attribute.Length.isNull)
                            {
                                description.put("(");
                                description.put(attribute.Length.to!string);
                                
                                if (attribute.CharUsedBOrC == "B")
                                    description.put(" BYTE");
                                else if (attribute.CharUsedBOrC == "C")
                                    description.put(" CHAR");
                                
                                description.put(")");
                            }
                            else if (!attribute.Precision.isNull)
                            {
                                description.put("(");
                                description.put(attribute.Precision.get.to!string);
                                
                                if (!attribute.Scale.isNull)
                                {
                                    description.put(", ");
                                    description.put(attribute.Scale.get.to!string);
                                }
                                
                                description.put(")");
                            }
                            
                            if (attribute.CharacterSetName.length > 0)
                            {
                                description.put(" ");
                                description.put(attribute.CharacterSetName);
                            }
                            
                            if (attribute.Inherited == "YES")
                                description.put(" INHERITED");
                            
                            description.put(lineEnding);
                        }
                        
                        auto describeTypeMethodsSql = 
                            "SELECT method_name,              \n" ~ 
                            "       method_no,                \n" ~ 
                            "       method_type,              \n" ~ 
                            "       parameters,               \n" ~ 
                            "       results,                  \n" ~ 
                            "       final,                    \n" ~ 
                            "       instantiable,             \n" ~ 
                            "       overriding,               \n" ~ 
                            "       inherited                 \n" ~ 
                            "  FROM all_type_methods          \n" ~ 
                            " WHERE owner = :p_schema         \n" ~ 
                            "   AND type_name = :p_type_name  \n" ~ 
                            " ORDER BY method_no ASC          \n";
                        
                        alias MethodResult = Tuple!(
                            string, "Name", 
                            long,   "Number", 
                            string, "Type", 
                            long,   "ParameterCount", 
                            long,   "ResultCount", 
                            string, "Final", 
                            string, "Instantiable", 
                            string, "Overriding", 
                            string, "Inherited");
                        
                        auto methods = ExecuteSynchronous!MethodResult(
                            describeTypeMethodsSql, 
                            createInputBinding("p_schema", type.Schema), 
                            createInputBinding("p_type_name", type.ObjectName));
                        
                        foreach (method; methods)
                        {
                            description.put(lineEnding);
                            description.put("    ");
                            
                            if (method.Type.length > 0)
                            {
                                description.put(method.Type);
                                description.put(" ");
                            }
                            
                            if (method.Final == "YES")
                                description.put("FINAL ");
                            
                            if (method.Instantiable == "YES")
                                description.put("INSTANTIABLE ");
                            
                            if (method.Overriding == "YES")
                                description.put("OVERRIDING ");
                            
                            if (method.Inherited == "YES")
                                description.put("INHERITED ");
                            
                            description.put(method.Name);
                            description.put("(");
                            
                            auto parametersSql = 
                                "SELECT param_name,                   \n" ~ 
                                "       param_mode,                   \n" ~ 
                                "       param_type_mod,               \n" ~ 
                                "       param_type_owner,             \n" ~ 
                                "       param_type_name,              \n" ~ 
                                "       character_set_name            \n" ~ 
                                "  FROM all_method_params             \n" ~ 
                                " WHERE owner       = :p_schema       \n" ~ 
                                "   AND type_name   = :p_type_name    \n" ~ 
                                "   AND method_name = :p_method_name  \n" ~ 
                                "   AND method_no   = :p_method_no    \n" ~ 
                                " ORDER BY param_no ASC               \n";
                            
                            alias ParameterResult = Tuple!(
                                string, "Name", 
                                string, "Mode", 
                                string, "TypeModifier", 
                                string, "TypeOwner", 
                                string, "TypeName", 
                                string, "CharacterSetName");
                            
                            auto parameters = ExecuteSynchronous!ParameterResult(
                                parametersSql, 
                                createInputBinding("p_schema",      type.Schema), 
                                createInputBinding("p_type_name",   type.ObjectName), 
                                createInputBinding("p_method_name", method.Name), 
                                createInputBinding("p_method_no",   method.Number));
                            
                            auto maximumParameterNameLength = parameters.map!(p => p.Name.toUtf8Slice.intLength).reduceMax(0);
                            
                            foreach (parameterIndex, parameter; parameters)
                            {
                                if (parameterIndex > 0)
                                    description.put(", ");
                                
                                description.put(lineEnding);
                                description.put("        ");
                                description.put(parameter.Name.leftJustify(maximumParameterNameLength));
                                description.put(" ");
                                
                                if (parameter.Mode.length > 0)
                                {
                                    description.put(parameter.Mode);
                                    description.put(" ");
                                }
                                
                                if (parameter.TypeModifier.length > 0)
                                {
                                    description.put(parameter.TypeModifier);
                                    description.put(" ");
                                }
                                
                                if (parameter.TypeOwner.length > 0)
                                {
                                    description.put(parameter.TypeOwner);
                                    description.put(".");
                                }
                                
                                description.put(parameter.TypeName);
                                
                                if (parameter.CharacterSetName.length > 0)
                                {
                                    description.put(" ");
                                    description.put(parameter.CharacterSetName);
                                }
                            }
                            
                            description.put(")");
                            description.put(lineEnding);
                            
                            auto returnTypeSql = 
                                "SELECT result_type_mod,              \n" ~ 
                                "       result_type_owner,            \n" ~ 
                                "       result_type_name,             \n" ~ 
                                "       character_set_name            \n" ~ 
                                "  FROM all_method_results            \n" ~ 
                                " WHERE owner       = :p_schema       \n" ~ 
                                "   AND type_name   = :p_type_name    \n" ~ 
                                "   AND method_name = :p_method_name  \n" ~ 
                                "   AND method_no   = :p_method_no    \n";
                            
                            alias returnTypesResult = Tuple!(
                                string, "TypeModifier", 
                                string, "TypeOwner", 
                                string, "TypeName", 
                                string, "CharacterSetName");
                            
                            auto returnTypes = ExecuteSynchronous!returnTypesResult(
                                returnTypeSql, 
                                createInputBinding("p_schema",      type.Schema), 
                                createInputBinding("p_type_name",   type.ObjectName), 
                                createInputBinding("p_method_name", method.Name), 
                                createInputBinding("p_method_no",   method.Number));
                            
                            if (returnTypes.length > 0)
                                description.put("        RETURN ");
                            
                            foreach (returnTypeIndex, returnType; returnTypes)
                            {
                                if (returnTypeIndex > 0)
                                {
                                    description.put(", ");
                                    description.put(lineEnding);
                                    description.put("               ");
                                }
                                
                                if (returnType.TypeModifier.length > 0)
                                {
                                    description.put(returnType.TypeModifier);
                                    description.put(" ");
                                }
                                
                                if (returnType.TypeOwner.length > 0)
                                {
                                    description.put(returnType.TypeOwner);
                                    description.put(".");
                                }
                                
                                description.put(returnType.TypeName);
                                
                                if (returnType.CharacterSetName.length > 0)
                                {
                                    description.put(" ");
                                    description.put(returnType.CharacterSetName);
                                }
                            }
                            
                            if (returnTypes.length > 0)
                                description.put(";");
                            
                            description.put(lineEnding);
                        }
                    }
                    
                    stopWatch.stop;
                    
                    reply(MessageResultType.Information, description.data, true);
                    reply(SqlSuccess(0, false, CommitState.Uncommitted, "", stopWatch.peek, true));
                    return;
                    
                default: 
                    reply(MessageResultType.Failure, "DESCRIBE " ~ objectType ~ " not available." ~ lineEnding);
                    return;
            }
        }
        else if (instructionType == ObjectInstruction.Types.ShowSource) 
        {
            string describeProcedureSql;
            
            if (objectType == "VIEW")
                describeProcedureSql = 
                    "SELECT text                            \n" ~ 
                    "  FROM all_views" ~ atDatabaseLink ~  "\n" ~ 
                    " WHERE owner = NVL(:p_schema, owner)   \n" ~ 
                    "   AND view_name = :p_object_name      \n" ~ 
                    "   AND (    :p_schema IS NOT NULL      \n" ~ 
                    "         OR owner = 'PUBLIC'           \n" ~ 
                    "         OR owner = :p_current_schema) \n";
            else
                describeProcedureSql = 
                    "SELECT TRIM(CHR(10) FROM TRIM(CHR(13) FROM text)) AS text \n" ~ 
                    "  FROM all_source" ~ atDatabaseLink ~ "\n" ~ 
                    " WHERE owner = NVL(:p_schema, owner)   \n" ~ 
                    "   AND name = :p_object_name           \n" ~ 
                    "   AND (    :p_schema IS NOT NULL      \n" ~ 
                    "         OR owner = 'PUBLIC'           \n" ~ 
                    "         OR owner = :p_current_schema) \n" ~ 
                    " ORDER BY owner,                       \n" ~ 
                    "          name,                        \n" ~ 
                    "          type,                        \n" ~ 
                    "          line                         \n";
            
            auto stopWatch = StopWatch(AutoStart.yes);
            
            alias Result = Tuple!(string, "text");
            
            auto sourceLines = ExecuteSynchronous!Result(
                describeProcedureSql, 
                createInputBinding("p_schema",          name.Schema), 
                createInputBinding("p_object_name",     name.ObjectName), 
                createInputBinding("p_current_schema",  currentSchema));
            
            foreach (line; sourceLines)
                reply(MessageResultType.Information, line.text.replace("\r\n", "\0\0").replace("\n", "\0\0").replace("\0\0", "\r\n"), true);
            
            stopWatch.stop;
            reply(SqlSuccess(0, false, CommitState.Uncommitted, "", stopWatch.peek, true));
        }
    }
    
    SqlError lastPlSqlError;
    string lastPlSqlObjectType;
    OracleObjectName lastPlSqlObjectName;
    
    void ShowErrors(const OracleObjectName name, const string type)
    {
        string tempType = type;
        OracleObjectName tempName = name;
        
        if (type.length == 0 && name.ObjectName.length == 0)
        {
            if (lastPlSqlError.Error.length > 0)
            {    
                reply(lastPlSqlError);
                return;
            }
            
            tempType = lastPlSqlObjectType;
            tempName = lastPlSqlObjectName;
        }
        
        enum plSqlErrorSql = 
            "SELECT owner     AS \"Owner\",      " ~ 
            "       name      AS \"Name\",       " ~ 
            "       type      AS \"Type\",       " ~ 
            "       line      AS \"Line\",       " ~ 
            "       position  AS \"Column\",     " ~ 
            "       text      AS \"Error\",      " ~ 
            "       attribute AS \"Attribute\"   " ~ 
            "  FROM all_errors                   " ~ 
            " WHERE owner = NVL(:p_owner, owner) " ~ 
            "   AND name  = NVL(:p_name,  name)  " ~ 
            "   AND type  = NVL(:p_type,  type)  " ~ 
            " ORDER BY                           " ~ 
            "       owner,                       " ~ 
            "       name,                        " ~ 
            "       type,                        " ~ 
            "       line,                        " ~ 
            "       position,                    " ~ 
            "       sequence                     ";
        
        Execute(plSqlErrorSql, 0, false, 
            createInputBinding("p_owner", tempName.Schema), 
            createInputBinding("p_name", tempName.ObjectName), 
            createInputBinding("p_type", tempType));
    }
    
    public auto createInputBinding(TValue)(string name, TValue value)
    {
        return new InputBindVariable!TValue(name, value);
    }
    
    private class BindVariable
    {
        string name;
        OCIBind* binding;
        int initialLength = 0;
        abstract void* nullIndicatorAddress();
        abstract ushort* bufferLengthAddress();
        abstract ushort* returnCodeAddress();
        abstract void* valueAddress();
        uint maxArraySize = 0;
        uint currentArraySize = 0;
        abstract ushort typeCode();
    }
    
    private final class InputBindVariable(TValue) : BindVariable
        if (is(TValue == string) || isIntegral!TValue)
    {
        enum isString = is(TValue == string);
        TValue value;
        
        short nullIndicator;
        ushort bufferLength;
        
        this(string name, TValue value)
        {
            this.name = name;
            this.value = value;
            
            static if (isString)
                this.nullIndicator = value.length == 0 ? -1 : 0;
            else
                this.nullIndicator = 0;
            
            static if (isString)
            {
                this.initialLength = cast(int   )value.length;
                this.bufferLength  = cast(ushort)value.length;
            }
            else 
            {
                this.initialLength = TValue.sizeof;
                this.bufferLength  = TValue.sizeof;
            }
        }
        
        override void* valueAddress()
        {
            static if (isString)
                return cast(void*)value.ptr;
            else
                return &value;
        }
        
        override void* nullIndicatorAddress()
        {
            return &nullIndicator;
        }
        
        override ushort* bufferLengthAddress()
        {
            return &bufferLength;
        }
        
        override ushort* returnCodeAddress()
        {
            return null;
        }
        
        override ushort typeCode()
        {
            static if (isString)
                return SQLT_CHR;
            else
                return SQLT_INT;
        }
    }
    
    private final class InputOutputBindVariable(TValue, size_t outputBufferLength = TValue.sizeof) : BindVariable
    // if (is(TValue == string) || isIntegral!TValue)
    {
        enum isString = is(TValue == string);
        
        ubyte[outputBufferLength] buffer = 0;
        short nullIndicator;
        ushort bufferLength;
        ushort returnCode;
        
        this(string name)
        {
            this.name = name;
            this.nullIndicator = -1;
            this.initialLength = outputBufferLength;
            this.bufferLength = outputBufferLength;
            this.maxArraySize = 0;
            this.returnCode = 0;
        }
        
        TValue result()
        {
            static if (isString)
                return (cast(char[])buffer[0 .. bufferLength]).to!string;
            else
                return *cast(TValue*)(buffer.ptr);
        }
        
        void result(TValue newValue)
        {
            static if (isString)
            {
                immutable length = min(newValue.length, outputBufferLength);
                buffer[0 .. length] = cast(ubyte[])newValue[0 .. length]; // Untested.
            }
            else
                buffer[0 .. outputBufferLength] = (cast(ubyte*)&newValue)[0 .. outputBufferLength];
        }      
        
        override void* nullIndicatorAddress()
        {
            return &nullIndicator;
        }
        
        override ushort* bufferLengthAddress()
        {
            return &bufferLength;
        }
        
        override ushort* returnCodeAddress()
        {
            return &returnCode;
        }
        
        override void* valueAddress()
        {
            return buffer.ptr;
        }
        
        override ushort typeCode()
        {
            static if (isString)
                return SQLT_CHR;
            else
                return SQLT_INT;
        }
    }
    
    private final class StringVarrayOutputBindVariable : BindVariable
    {
        OCIArray* varray = null;
        
        this(string name)
        {
            this.name = name;
        }
        
        override void* nullIndicatorAddress()
        {
            return null;
        }
        
        override ushort* bufferLengthAddress()
        {
            return null;
        }
        
        override ushort* returnCodeAddress()
        {
            return null;
        }
        
        override void* valueAddress()
        {
            return null;
        }
        
        override ushort typeCode()
        {
            return SQLT_NTY;
        }
        
        public void processResult(alias process)()
        {
            OCIIter* iterator; 
            OCIIterCreate(
                environment, 
                error, 
                varray, 
                &iterator)
                .checkResult(error, &reportWarning);
            
            scope (exit) 
                OCIIterDelete(
                    environment, 
                    error, 
                    &iterator)
                    .checkResult(error, &reportWarning);
            
            while (true)
            {
                OCIString** element;
                OCIInd* element_indicator;
                int isEndOfCollection;
                
                OCIIterNext(
                    environment, 
                    error, 
                    iterator, 
                    cast(void**)&element,
                    cast(void**)&element_indicator, 
                    &isEndOfCollection)
                    .checkResult(error, &reportWarning);

                if (isEndOfCollection)
                    break;
                
                process((cast(char*)OCIStringPtr(environment, *element)).FromCString);
            }
        }
    }
    
    // This didn't work in my scenario, but it wasn't a regular bulk bind, 
    // so I'm keeping it around in case it's useful in the future.
    private final class OutputArrayBindVariable(TValue, size_t outputBufferLength, size_t staticMaxArraySize) : BindVariable
        if (is(TValue == string) || isIntegral!TValue)
    {
        enum isString = is(TValue == string);
        
        ubyte[outputBufferLength][staticMaxArraySize] buffer;
        short[staticMaxArraySize] nullIndicators;
        ushort[staticMaxArraySize] bufferLengths;
        ushort[staticMaxArraySize] returnCodes;
        
        this(string name)
        {
            this.name = name;
            this.nullIndicators = 0;
            this.initialLength = outputBufferLength;
            this.bufferLengths = outputBufferLength;
            this.maxArraySize = staticMaxArraySize;
            this.currentArraySize = 0;
        }
        
        TValue result(size_t index)
        {
            static if (isString)
                return (cast(char[])buffer[index][0 .. outputBufferLength]).to!string;
            else
                return *cast(TValue*)(buffer[index].ptr);
        }
        
        override void* nullIndicatorAddress()
        {
            return nullIndicators.ptr;
        }
        
        override ushort* bufferLengthAddress()
        {
            return bufferLengths.ptr;
        }
        
        override ushort* returnCodeAddress()
        {
            return returnCodes.ptr;
        }
        
        override void* valueAddress()
        {
            return buffer.ptr;
        }
        
        override ushort typeCode()
        {
            static if (isString)
                return SQLT_CHR;
            else
                return SQLT_INT;
        }
    }
    
    bool[string] defaultedFieldExistsForDbLink;
    bool DefaultedFieldExists(const string atDbLinkName = "")
    {
        const defaultedFieldExistsRef = atDbLinkName in defaultedFieldExistsForDbLink;
        if (defaultedFieldExistsRef !is null)
            return *defaultedFieldExistsRef;
        
        const checkSql = 
            "SELECT 1                                \n" ~ 
            "  FROM all_tab_columns" ~ atDbLinkName ~ "\n" ~ 
            " WHERE owner = 'SYS'                    \n" ~ 
            "   AND table_name = 'ALL_ARGUMENTS'     \n" ~ 
            "   AND column_name = 'DEFAULTED'        \n" ~ 
            "   AND ROWNUM = 1                       \n";
        
        auto results = ExecuteSynchronous!(Tuple!(long, "Dummy"))(checkSql);
        
        const defaultedFieldExists = results.length > 0;
        
        defaultedFieldExistsForDbLink[atDbLinkName] = defaultedFieldExists;
        
        return defaultedFieldExists;
    }
    
    
    private class Statement
    {
        OCIStmt* statement;
        DatabaseValue[] values;
        immutable(OracleColumn)[] columns;
        uint statementType;
        
        enum Type { nonQuery, selectWithNoRows, selectWithRows };
        
        // I created this enum because I had mixed results from various sources:
        //    1) The OCI header file only has 56 entries and has awful names.
        //    2) The OCI documentation has 126 entries.
        //    3) OCILIB has 239 entries however some of them are wrong and disagree with the other sources.
        //    4) The OCILIB D bindings have 124 entries (and corrected some mistakes).
        // 
        // So this list is cobbled together from the above.
        enum FunctionCode
        {
            CreateTable                      = 1, 
            SetRole                          = 2, 
            Insert                           = 3, 
            Select                           = 4, 
            Update                           = 5, 
            DropRole                         = 6, 
            DropView                         = 7, 
            DropTable                        = 8, 
            Delete                           = 9, 
            CreateView                       = 10, 
            DropUser                         = 11, 
            CreateRole                       = 12, 
            CreateSequence                   = 13, 
            AlterSequence                    = 14, 
            DropSequence                     = 16, 
            CreateSchema                     = 17, 
            CreateCluster                    = 18, 
            CreateUser                       = 19, 
            CreateIndex                      = 20, 
            DropIndex                        = 21, 
            DropCluster                      = 22, 
            ValidateIndex                    = 23, 
            CreateProcedure                  = 24, 
            AlterProcedure                   = 25, 
            AlterTable                       = 26, 
            Explain                          = 27, 
            Grant                            = 28, 
            Revoke                           = 29, 
            CreateSynonym                    = 30, 
            DropSynonym                      = 31, 
            AlterSystemSwitchlog             = 32, 
            SetTransaction                   = 33, 
            PlsqlExecute                     = 34, 
            Lock                             = 35, 
            Noop                             = 36, 
            Rename                           = 37, 
            Comment                          = 38, 
            Audit                            = 39, 
            NoAudit                          = 40, 
            AlterIndex                       = 41, 
            CreateExternalDatabaseLink       = 42, 
            DropExternaldatabaseLink         = 43, 
            CreateDatabase                   = 44, 
            AlterDatabase                    = 45, 
            CreateRollbackSegment            = 46, 
            AlterRollbackSegment             = 47, 
            DropRollbackSegment              = 48, 
            CreateTablespace                 = 49, 
            AlterTablespace                  = 50, 
            DropTablespace                   = 51, 
            AlterSession                     = 52, 
            AlterUser                        = 53, 
            CommitWork                       = 54, 
            Rollback                         = 55, 
            Savepoint                        = 56, 
            CreateControlFile                = 57, 
            AlterTracing                     = 58, 
            CreateTrigger                    = 59, 
            AlterTrigger                     = 60, 
            DropTrigger                      = 61, 
            AnalyzeTable                     = 62, 
            AnalyzeIndex                     = 63, 
            AnalyzeCluster                   = 64, 
            CreateProfile                    = 65, 
            DropProfile                      = 66, 
            AlterProfile                     = 67, 
            DropProcedure                    = 68, 
            AlterResourceCost                = 70, 
            CreateSnapshotLog                = 71, 
            AlterSnapshotLog                 = 72, 
            DropSnapshotLog                  = 73, 
            CreateSnapshot                   = 74, 
            AlterSnapshot                    = 75, 
            DropSnapshot                     = 76, 
            CreateType                       = 77, 
            DropType                         = 78, 
            AlterRole                        = 79, 
            AlterType                        = 80, 
            CreateTypeBody                   = 81, 
            AlterTypeBody                    = 82, 
            DropTypeBody                     = 83, 
            DropLibrary                      = 84, 
            TruncateTable                    = 85, 
            TruncateCluster                  = 86, 
            CreateBitmapfile                 = 87, 
            AlterView                        = 88, 
            DropBitmapfile                   = 89, 
            SetConstraints                   = 90, 
            CreateFunction                   = 91, 
            AlterFunction                    = 92, 
            DropFunction                     = 93, 
            CreatePackage                    = 94, 
            AlterPackage                     = 95, 
            DropPackage                      = 96, 
            CreatePackageBody                = 97, 
            AlterPackageBody                 = 98, 
            DropPackageBody                  = 99, 
            Logon                            = 100, 
            Logoff                           = 101, 
            LogoffByCleanup                  = 102, 
            SessionRec                       = 103, 
            SystemAudit                      = 104, 
            SystemNoaudit                    = 105, 
            AuditDefault                     = 106, 
            NoauditDefault                   = 107, 
            SystemGrant                      = 108, 
            SystemRevoke                     = 109, 
            CreatePublicSynonym              = 110, 
            DropPublicSynonym                = 111, 
            CreatePublicDatabaseLink         = 112, 
            DropPublicDatabaseLink           = 113, 
            GrantRole                        = 114, 
            RevokeRole                       = 115, 
            ExecuteProcedure                 = 116, 
            UserComment                      = 117, 
            EnableTrigger                    = 118, 
            DisableTrigger                   = 119, 
            EnableAllTriggers                = 120, 
            DisableAllTriggers               = 121, 
            NetworkError                     = 122, 
            ExecuteType                      = 123, 
            ReadDirectory                    = 125, 
            WriteDirectory                   = 126, 
            Flashback                        = 128, 
            BecomeUser                       = 129, 
            AlterMiningModel                 = 130, 
            SelectMiningModel                = 131, 
            CreateMiningModel                = 133, 
            AlterPublicSynonym               = 134, 
            ExecuteDirectory                 = 135, 
            SqlLoaderDirectPathLoad          = 136, 
            DatapumpDirectPathUnload         = 137, 
            DatabaseStartup                  = 138, 
            DatabaseShutdown                 = 139, 
            CreateSqlTxlnProfile             = 140, 
            AlterSqlTxlnProfile              = 141, 
            UseSqlTxlnProfile                = 142, 
            DropSqlTxlnProfile               = 143, 
            CreateMeasureFolder              = 144, 
            AlterMeasureFolder               = 145, 
            DropMeasureFolder                = 146, 
            CreateCubeBuildProcess           = 147, 
            AlterCubeBuildProcess            = 148, 
            DropCubeBuildProcess             = 149, 
            CreateCube                       = 150, 
            AlterCube                        = 151, 
            DropCube                         = 152, 
            CreateCubeDimension              = 153, 
            AlterCubeDimension               = 154, 
            DropCubeDimension                = 155, 
            CreateDirectory                  = 157, 
            DropDirectory                    = 158, 
            CreateLibrary                    = 159, 
            CreateJava                       = 160, 
            AlterJava                        = 161, 
            DropJava                         = 162, 
            CreateOperator                   = 163, 
            CreateIndextype                  = 164, 
            DropIndextype                    = 165, 
            AlterIndextype                   = 166, 
            DropOperator                     = 167, 
            AssociateStatistics              = 168, 
            DisassociateStatistics           = 169, 
            CallMethod                       = 170, 
            CreateSummary                    = 171, 
            AlterSummary                     = 172, 
            DropSummary                      = 173, 
            CreateDimension                  = 174, 
            AlterDimension                   = 175, 
            DropDimension                    = 176, 
            CreateContext                    = 177, 
            DropContext                      = 178, 
            AlterOutline                     = 179, 
            CreateOutline                    = 180, 
            DropOutline                      = 181, 
            UpdateIndexes                    = 182, 
            AlterOperator                    = 183, 
            CreateSpfile                     = 187, 
            CreatePfile                      = 188, 
            Merge                            = 189, 
            PasswordChange                   = 190, 
            AlterSynonym                     = 192, 
            AlterDiskgroup                   = 193, 
            CreateDiskgroup                  = 194, 
            DropDiskgroup                    = 195, 
            PurgeRecyclebin                  = 197, 
            PurgeDbaRecyclebin               = 198, 
            PurgeTablespace                  = 199, 
            PurgeTable                       = 200, 
            PurgeIndex                       = 201, 
            UndropObject                     = 202, 
            DropDatabase                     = 203, 
            FlashbackDatabase                = 204, 
            FlashbackTable                   = 205, 
            CreateRestorePoint               = 206, 
            DropRestorePoint                 = 207, 
            ProxyAuthenticationOnly          = 208, 
            DeclareRewriteEquivalence        = 209, 
            AlterRewriteEquivalence          = 210, 
            DropRewriteEquivalence           = 211, 
            CreateEdition                    = 212, 
            AlterEdition                     = 213, 
            DropEdition                      = 214, 
            DropAssembly                     = 215, 
            CreateAssembly                   = 216, 
            AlterAssembly                    = 217, 
            CreateFlashbackArchive           = 218, 
            AlterFlashbackArchive            = 219, 
            DropFlashbackArchive             = 220, 
            DebugConnect                     = 221, 
            DebugProcedure                   = 223, 
            AlterDatabaseLink                = 225, 
            CreatePluggableDatabase          = 226, 
            AlterPluggableDatabase           = 227, 
            DropPluggableDatabase            = 228, 
            CreateAuditPolicy                = 229, 
            AlterAuditPolicy                 = 230, 
            DropAuditPolicy                  = 231, 
            CodeBasedGrant                   = 232, 
            CodeBasedRevoke                  = 233, 
            CreateLockdownProfile            = 234, 
            DropLockdownProfile              = 235, 
            AlterLockdownProfile             = 236, 
            TranslateSql                     = 237, 
            AdministerKeyManagement          = 238, 
            CreateMaterializedZonemap        = 239, 
            AlterMaterializedZonemap         = 240, 
            DropMaterializedZonemap          = 241, 
            DropMiningModel                  = 242, 
            CreateAttributeDimension         = 243, 
            AlterAttributeDimension          = 244, 
            DropAttributeDimension           = 245, 
            CreateHierarchy                  = 246, 
            AlterHierarchy                   = 247, 
            DropHierarchy                    = 248, 
            CreateAnalyticView               = 249, 
            AlterAnalyticView                = 250, 
            DropAnalyticView                 = 251, 
            AlterPublicDatabaseLink          = 305, 
        };        
        
        this()
        {
            statement = allocateHandle!OCIStmt;
        }
        
        void free()
        {
            OCIHandleFree(statement, handleType!statement).checkResult(environment, &report);
            GC.free(cast(void*)this);
        }
        
        FunctionCode functionCode()
        {
            return cast(FunctionCode)getAttribute!uint(statement, OCI_ATTR_SQLFNCODE);
        }
        
        ushort errorOffset()
        {
             return getAttribute!ushort(statement, OCI_ATTR_PARSE_ERROR_OFFSET);
        }
        
        uint affectedRows()
        {
            return getAttribute!uint(statement, OCI_ATTR_ROW_COUNT);
        }
        
        private class DatabaseValue
        {
            OCIDefine*          define;
            ubyte[]             data;
            short               nullIndicator;
            ushort              length;
            IntermediateType    intermediateType;
            DescriptorCategory  descriptorCategory;
            uint                descriptorCode;
            string              dateFormat;
            ubyte               fractionalPrecision;
            
            this(
                const uint oracleDataType, 
                const uint scale, 
                const uint precision, 
                const ubyte fractionalPrecision) @nogc nothrow
            {
                this.fractionalPrecision = fractionalPrecision;
            
                // There are a lot of data types here and I don't understand many of them.  
                // I think some are just for translation, so should not be provided by Oracle 
                // (hopefully), but I've tried to categorise as many as possible anyway.
                
                switch (oracleDataType)
                {
                    case SQLT_NUM, // (ORANET TYPE) oracle numeric
                         SQLT_INT, // (ORANET TYPE) integer
                         SQLT_VNU, // NUM with preceding length byte
                         SQLT_PDN, // (ORANET TYPE) Packed Decimal Numeric
                         SQLT_UIN: // unsigned integer
                        
                        intermediateType = IntermediateType.Number;
                        break;
                    
                    case SQLT_CHR: // (ORANET TYPE) character string
                        intermediateType = IntermediateType.String;
                        break;
                        
                    case SQLT_FLT: // (ORANET TYPE) Floating point number
                        intermediateType = IntermediateType.Number;
                        break;
                        
                    case SQLT_STR: // Zero terminated string
                        intermediateType = IntermediateType.String;
                        break;
                        
                    case SQLT_LNG: // Long
                        intermediateType = IntermediateType.String;
                        break;
                        
                    case SQLT_VCS: // Variable character string
                        intermediateType = IntermediateType.String;
                        break;
                        
                    case SQLT_NON: // Null/empty PCC Descriptor entry
                        intermediateType = IntermediateType.Unsupported;
                        data = cast(ubyte[])"[Empty PCC Descriptor]";
                        break;
                        
                    case SQLT_RID: // Rowid
                        intermediateType = IntermediateType.String;
                        break;
                        
                    case SQLT_VBI: // Binary in VCS format
                        intermediateType = IntermediateType.Unsupported;
                        data = cast(ubyte[])"[Binary VCS Format]";
                        break;
                        
                    case SQLT_BFLOAT: // Native Binary float
                        intermediateType = IntermediateType.Number;
                        break;
                        
                    case SQLT_BDOUBLE: // Native binary double 
                        intermediateType = IntermediateType.Number;
                        break;
                        
                    case SQLT_BIN: // Binary data(DTYBIN)
                        intermediateType = IntermediateType.String;
                        break;
                        
                    case SQLT_LBI: // Long binary
                        intermediateType = IntermediateType.Unsupported;
                        data = cast(ubyte[])"[Long Binary]";
                        break;
                        
                    case SQLT_SLS: // Display sign leading separate
                        intermediateType = IntermediateType.Unsupported;
                        data = cast(ubyte[])"[Display Sign Leading Separate]";
                        break;
                        
                    case SQLT_LVC: // Longer longs (char)
                        intermediateType = IntermediateType.String;
                        break;
                        
                    case SQLT_LVB: // Longer long binary
                        intermediateType = IntermediateType.Unsupported;
                        data = cast(ubyte[])"[Longer Long Binary]";
                        break;
                        
                    case SQLT_AFC: // Ansi fixed char
                        intermediateType = IntermediateType.String;
                        break;
                        
                    case SQLT_AVC: // Ansi Var char
                        intermediateType = IntermediateType.String;
                        break;
                        
                    case SQLT_IBFLOAT: // Binary float canonical
                        intermediateType = IntermediateType.Number;
                        break;
                        
                    case SQLT_IBDOUBLE: // Binary double canonical
                        intermediateType = IntermediateType.Number;
                        break;
                        
                    case SQLT_CUR: // Cursor  type
                        intermediateType = IntermediateType.Unsupported;
                        data = cast(ubyte[])"[Cursor]";
                        break;
                        
                    case SQLT_RDD: // Rowid descriptor
                        // intermediateType   = IntermediateType.Descriptor;
                        // descriptorCategory = DescriptorCategory.Rowid;
                        // descriptorCode     = OCI_DTYPE_ROWID;
                        intermediateType   = IntermediateType.String;
                        
                        break;
                        
                    case SQLT_LAB: // Label type
                        intermediateType = IntermediateType.Unsupported;
                        data = cast(ubyte[])"[Label]";
                        break;
                        
                    case SQLT_OSL: // Oslabel type
                        intermediateType = IntermediateType.Unsupported;
                        data = cast(ubyte[])"[OS Label]";
                        break;
                        
                    case SQLT_NTY: // Named object type
                        intermediateType = IntermediateType.Unsupported;
                        data = cast(ubyte[])"[Named Object]";
                        break;
                        
                    case SQLT_REF: // Ref type
                        intermediateType = IntermediateType.Unsupported;
                        data = cast(ubyte[])"[Ref Type]";
                        break;
                        
                    case SQLT_CLOB: // Character lob
                        intermediateType    = IntermediateType.Descriptor;
                        descriptorCategory  = DescriptorCategory.Lob;
                        descriptorCode      = OCI_DTYPE_LOB;
                        break;
                        
                    case SQLT_BLOB: // Binary lob
                        intermediateType = IntermediateType.Unsupported;
                        descriptorCategory = DescriptorCategory.Lob;
                        descriptorCode      = OCI_DTYPE_LOB;
                        data = cast(ubyte[])"[Binary Large Object]";
                        break;
                        
                    case SQLT_BFILEE: // Binary file lob
                        intermediateType   = IntermediateType.Unsupported;
                        descriptorCategory = DescriptorCategory.Lob;
                        descriptorCode     = OCI_DTYPE_FILE;
                        data = cast(ubyte[])"[Binary File Large Object]";
                        break;
                        
                    case SQLT_CFILEE: // Character file lob
                        intermediateType   = IntermediateType.Descriptor;
                        descriptorCategory = DescriptorCategory.Lob;
                        descriptorCode     = OCI_DTYPE_FILE;
                        break;
                        
                    case SQLT_RSET: // Result set type
                        intermediateType = IntermediateType.Unsupported;
                        data = cast(ubyte[])"[Result Set]";
                        break;
                        
                    case SQLT_NCO: // Named collection type (varray or nested table)
                        intermediateType = IntermediateType.Unsupported;
                        data = cast(ubyte[])"[Collection]";
                        break;
                        
                    case SQLT_VST: // OCIString type
                        intermediateType = IntermediateType.String;
                        break;
                        
                    case SQLT_DAT:  // Date in oracle format
                    case SQLT_DATE: // ANSI Date
                    case SQLT_ODT:  // OCIDate type
                        intermediateType = IntermediateType.DateTime;
                        dateFormat       = nlsDateFormat;
                        break;
                    
                    // // I can get the formats for these from nls_session_parameters, but 
                    // // I have no idea how to create values or columns of these types.
                    // case SQLT_TIME: // TIME
                    //     intermediateType    = IntermediateType.Descriptor;
                    //     descriptorCategory  = DescriptorCategory.DateTime;
                    //     descriptorCode      = OCI_DTYPE_TIMESTAMP;
                    //     dateFormat          = nlsTimeFormat;
                    //     break;
                    //     
                    // case SQLT_TIME_TZ: // TIME WITH TIME ZONE
                    //     intermediateType    = IntermediateType.Descriptor;
                    //     descriptorCategory  = DescriptorCategory.DateTime;
                    //     descriptorCode      = OCI_DTYPE_TIMESTAMP;
                    //     dateFormat          = nlsTimeTimezoneFormat;
                    //     break;
                    
                    case SQLT_TIMESTAMP: // TIMESTAMP
                        intermediateType    = IntermediateType.Descriptor;
                        descriptorCategory  = DescriptorCategory.DateTime;
                        descriptorCode      = OCI_DTYPE_TIMESTAMP;
                        dateFormat          = nlsTimestampFormat;
                        break;
                        
                    case SQLT_TIMESTAMP_TZ: // TIMESTAMP WITH TIME ZONE
                        intermediateType    = IntermediateType.Descriptor;
                        descriptorCategory  = DescriptorCategory.DateTime;
                        descriptorCode      = OCI_DTYPE_TIMESTAMP_TZ;
                        dateFormat          = nlsTimestampTimezoneFormat;
                        break;
                        
                    case SQLT_TIMESTAMP_LTZ: // TIMESTAMP WITH LOCAL TZ
                        intermediateType    = IntermediateType.Descriptor;
                        descriptorCategory  = DescriptorCategory.DateTime;
                        descriptorCode      = OCI_DTYPE_TIMESTAMP_LTZ;
                        dateFormat          = nlsTimestampFormat;
                        break;
                        
                    case SQLT_INTERVAL_YM: // INTERVAL YEAR TO MONTH
                        intermediateType    = IntermediateType.Descriptor;
                        descriptorCategory  = DescriptorCategory.Interval;
                        descriptorCode      = OCI_DTYPE_INTERVAL_YM;
                        break;
                        
                    case SQLT_INTERVAL_DS: // INTERVAL DAY TO SECOND
                        intermediateType    = IntermediateType.Descriptor;
                        descriptorCategory  = DescriptorCategory.Interval;
                        descriptorCode      = OCI_DTYPE_INTERVAL_DS;
                        break;
                        
                    case SQLT_PNTY: // PL/SQL representation of named types
                        intermediateType = IntermediateType.Unsupported;
                        data = cast(ubyte[])"[PL/SQL Named Type]";
                        break;
                        
                    default:                 
                        intermediateType = IntermediateType.Unsupported;
                        data = cast(ubyte[])"[Unknown Data Type]";
                        break;
                }
            }
            
            T* getLocator(T)()
            {
                assert(intermediateType == IntermediateType.Descriptor);
                assert((descriptorCategory == DescriptorCategory.Lob      && is(T == OCILobLocator)) || 
                    // (descriptorCategory == DescriptorCategory.Rowid    && is(T == OCIRowid     )) || 
                       (descriptorCategory == DescriptorCategory.DateTime && is(T == OCIDateTime  )) || 
                       (descriptorCategory == DescriptorCategory.Interval && is(T == OCIInterval  )));
                
                // Locators are a pointer to a pointer here.
                // assert(data.length == 4);
                return cast(T*)*cast(size_t*)(data.ptr);
            }
        }
        
        void setPreFetchSize(uint prefectSize)
        {
            setAttribute!uint(statement, OCI_ATTR_PREFETCH_ROWS, prefectSize);
        }
        
        Type execute(string sql, int fetchSize, bool isSuccessWithInformationConsideredSuccess, BindVariable[] bindVariables)
        {
            setPreFetchSize(fetchSize);
            
            OCIStmtPrepare(
                statement, 
                error, 
                cast(const(ubyte)*)sql, 
                cast(uint)sql.length, 
                OCI_NTV_SYNTAX, 
                OCI_DEFAULT)
                .checkResult(error, &reportWarning);
            
            foreach (bindVariable; bindVariables)
            {
                OCIBindByName(
                    statement, 
                    &bindVariable.binding, 
                    error, 
                    cast(const(ubyte)*)bindVariable.name.ptr, 
                    cast(int)bindVariable.name.length, 
                    bindVariable.valueAddress, 
                    bindVariable.initialLength, 
                    bindVariable.typeCode, 
                    bindVariable.nullIndicatorAddress, 
                    bindVariable.bufferLengthAddress, 
                    bindVariable.returnCodeAddress, 
                    bindVariable.maxArraySize, 
                    bindVariable.maxArraySize == 0 ? null : &bindVariable.currentArraySize, 
                    OCI_DEFAULT)
                    .checkResult(error, &reportWarning);
                
                if (auto varrayBind = cast(StringVarrayOutputBindVariable)bindVariable)
                {
                    // TODO: the documentation says I should be caching this to reduce round-trips.
                    
                    OCIType_* typeName;
                    
                    OCITypeByName(
                        environment, 
                        error, 
                        serviceContext, 
                        cast(const(ubyte)*)"SYS".ptr, 
                        "SYS".length, 
                        cast(const(ubyte)*)"DBMSOUTPUT_LINESARRAY".ptr, 
                        "DBMSOUTPUT_LINESARRAY".length,  
                        null, 
                        0, 
                        OCI_DURATION_TRANS, 
                        OCITypeGetOpt.OCI_TYPEGET_HEADER, 
                        &typeName)
                        .checkResult(error, &reportWarning);
                    
                    OCIObjectNew(
                        environment, 
                        error, 
                        serviceContext, 
                        OCI_TYPECODE_VARRAY, 
                        typeName, 
                        null, 
                        OCI_DURATION_SESSION, 
                        true,
                        cast(void**)&varrayBind.varray)
                       .checkResult(error, &reportWarning);
                    
                    OCIBindObject(
                        bindVariable.binding, 
                        error, 
                        typeName, 
                        cast(void**)&varrayBind.varray, 
                        null, 
                        null, 
                        null)
                        .checkResult(error, &reportWarning);
                }
            }
            
            statementType = getAttribute!uint(statement, OCI_ATTR_STMT_TYPE);
            immutable uint initialRowFetchCount = statementType == OCI_STMT_SELECT ? 0 : 1;
            immutable executeResult = OCIStmtExecute(
                serviceContext, 
                statement, 
                error, 
                initialRowFetchCount, 
                0, 
                null, 
                null, 
                OCI_DEFAULT);
            
            if (executeResult == OCI_SUCCESS_WITH_INFO && isSuccessWithInformationConsideredSuccess)
                return Type.nonQuery;
            
            if (executeResult != OCI_NO_DATA)
                executeResult.checkResult(error, &reportWarning);            
            
            if (statementType != OCI_STMT_SELECT)
            {
                // If this is not a select statement, throw OCI_NO_DATA if we skipped over it above.
                executeResult.checkResult(error, &reportWarning);
                return Type.nonQuery;
            }
            
            if (executeResult == OCI_NO_DATA)
                return Type.selectWithNoRows;
            
            auto bindCount = 0;
            
            immutable columnCount = getAttribute!uint(statement, OCI_ATTR_PARAM_COUNT);
            for (auto columnIndex = 0; columnIndex < columnCount; columnIndex++)
            {
                OCIParam* parameterDescription;
                
                OCIParamGet(
                    cast(const(void)*)statement, 
                    handleType!statement, 
                    error, 
                    cast(void**)&parameterDescription, 
                    columnIndex + 1)
                    .checkResult(error, &reportWarning);
                
                immutable columnName = getAttributeText(parameterDescription, OCI_ATTR_NAME).dup;
                
                auto oracleType = getAttribute!ushort(parameterDescription, OCI_ATTR_DATA_TYPE);
                
                auto precision = getAttribute!short(parameterDescription, OCI_ATTR_PRECISION);
                if (precision == 0)
                    precision = 38;
                
                immutable fractionalPrecision = getAttribute!ubyte(parameterDescription, OCI_ATTR_FSPRECISION);
                
                // immutable intervalLeadingFieldSecondsPrecision = getAttribute!ubyte(parameterDescription, OCI_ATTR_LFPRECISION);
                
                auto scale = getAttribute!byte(parameterDescription, OCI_ATTR_SCALE);
                
                // if precision != 0 && scale is -127 then this is a float.
                
                auto size = getAttribute!uint(parameterDescription, OCI_ATTR_DATA_SIZE);
                
                auto value = new DatabaseValue(oracleType, scale, precision, fractionalPrecision);
                values ~= value;
                
                columns ~= new immutable OracleColumn(
                    columnName, 
                    () 
                    {
                        final switch (value.intermediateType) with (IntermediateType)
                        {
                            case Unsupported:  return OracleColumn.Types.Unsupported;
                            case String:       return OracleColumn.Types.String;
                            case Number:       return OracleColumn.Types.Number;
                            case DateTime:     return OracleColumn.Types.DateTime;  
                            case Descriptor:   return ()
                            {
                                final switch (value.descriptorCategory) with (DescriptorCategory)
                                {
                                    case None:     return OracleColumn.Types.Unsupported;
                                    case Lob:      return OracleColumn.Types.Unsupported;
                                    case DateTime: return OracleColumn.Types.DateTime;
                                    case Interval: return OracleColumn.Types.Unsupported;
                                }
                            }();
                        }
                    }(), 
                    () 
                    {
                        final switch (value.intermediateType) with (IntermediateType)
                        {
                            case Unsupported:  return cast(int)value.data.length;
                            case String:       return size;
                            case Number:       return precision + 2;
                            case DateTime:     return cast(int)value.dateFormat.length;
                            case Descriptor:   return 0;
                        }
                    }(), 
                    precision, 
                    scale);
                
                if (value.intermediateType == IntermediateType.Unsupported)
                    continue;
                
                auto convertedOracleType = cast(ushort)()
                {
                    final switch (value.intermediateType) with (IntermediateType)
                    {
                        case Unsupported: return SQLT_CHR;
                        case String:      return SQLT_CHR;
                        case Number:      return SQLT_VNU;
                        case DateTime:    return SQLT_ODT;
                        case Descriptor:  return oracleType;
                    }
                }();
                
                if (oracleType == SQLT_BIN)
                    size *= 2;
                else if (oracleType == SQLT_RID || oracleType == SQLT_RDD)
                    size = 20;
                else if (oracleType == SQLT_LNG || oracleType == SQLT_LBI)
                    // I'm not sure how I'm supposed to read LONG columns.  OCILIB sets "col->bufsize  = INT_MAX"
                    // which sounds like it's allocating 2GB.  I went with an upper limit of ushort.max because 
                    // one of the length parameters in OCIDefineByPos is ushort.
                    size = ushort.max;
                else if (value.intermediateType == IntermediateType.Descriptor)
                    size = 8;
                else if (value.intermediateType == IntermediateType.Number)
                    size = OCINumber.sizeof;
                
                value.data = new ubyte[size];
                
                if (value.intermediateType == IntermediateType.Descriptor)
                {
                    OCIDescriptorAlloc(
                        cast(void*)environment, 
                        cast(void**)value.data.ptr, 
                        value.descriptorCode, 
                        0, 
                        null)
                        .checkResult(environment, &report);
                    
                    if (value.descriptorCategory == DescriptorCategory.Lob)
                    {
                        auto locator = value.getLocator!OCILobLocator;
                        setAttribute!uint(locator, OCI_ATTR_LOBEMPTY, 0);
                    }
                }
                
                value.length = cast(ushort)value.data.length;
                
                OCIDefineByPos(
                    statement, 
                    &value.define, 
                    error, 
                    cast(uint)columnIndex + 1, 
                    cast(void*)value.data.ptr, 
                    cast(int)value.data.length, 
                    convertedOracleType, 
                    cast(void*)&value.nullIndicator, 
                    &value.length, 
                    null, 
                    OCI_DEFAULT)
                    .checkResult(error, &reportWarning);
                
                bindCount++;
            }
            
            if (bindCount == 0)
                throw new RecoverableException("There are no supported columns in this query.");
            
            return Type.selectWithRows;
        }
        
        immutable (OracleField)[] fetch()
        {
            immutable fetchResult = OCIStmtFetch2(
                statement, 
                error, 
                1, 
                OCI_FETCH_NEXT, 
                0, 
                OCI_DEFAULT);
            
            if (fetchResult == OCI_NO_DATA)
                return null;
            
            fetchResult.checkResult(error, &reportWarning);
            
            immutable(OracleField)[] fields;
            fields.reserve(columns.length);
            
            foreach (value; values)
            {
                if (value.nullIndicator == -1)
                {
                    fields ~= OracleField(NullField());
                    continue;
                }
                
                final switch (value.intermediateType)
                {
                    case IntermediateType.Unsupported: 
                        fields ~= OracleField((cast(char[])value.data).to!string);
                        break;
                        
                    case IntermediateType.String:      
                        fields ~= OracleField((cast(char[])value.data[0 .. value.length]).to!string);
                        break;
                        
                    case IntermediateType.Number:  
                        fields ~= OracleField(OracleNumber(value.data));
                        break;
                        
                    case IntermediateType.DateTime:    
                        auto oracleDate = cast(OCIDate*)value.data.ptr;
                        
                        static char[255] dateAsText;
                        uint dateLength = dateAsText.length;
                        
                        OCIDateToText(
                            error, 
                            oracleDate, 
                            cast(const(ubyte)*)value.dateFormat, 
                            cast(ubyte)value.dateFormat.length, 
                            null, 
                            cast(ulong)0, 
                            &dateLength, 
                            cast(ubyte*)dateAsText.ptr)
                            .checkResult(error, &reportWarning);
                        
                        short year;
                        ubyte month;
                        ubyte day;
                        ubyte hour;
                        ubyte minute;
                        ubyte second;
                        
                        OCIDateGetDate(
                            oracleDate, 
                            &year, 
                            &month, 
                            &day);
                        OCIDateGetTime(
                            oracleDate, 
                            &hour, 
                            &minute, 
                            &second);
                        
                        fields ~= OracleField(OracleDate(
                                    SysTime(DateTime(year, month, day, hour, minute, second), 
                                            dur!"nsecs"(0), UTC()), 
                                    dateAsText[0 .. dateLength].to!string));                        
                        break;
                        
                    case IntermediateType.Descriptor:  
                    
                        final switch (value.descriptorCategory)
                        {
                            case DescriptorCategory.None:
                                fields ~= OracleField(NullField());
                                break;
                                
                            case DescriptorCategory.Lob:
                                auto locator = value.getLocator!OCILobLocator;
                                
                                ulong lobLength;
                                OCILobGetLength2(
                                    serviceContext, 
                                    error, 
                                    locator, 
                                    &lobLength)
                                    .checkResult(error, &reportWarning);
                                
                                // Apparently I need to reserve x4 as much memory because the translation happens client 
                                // side.  When experimenting for some reason I received 1/3 the characters which I wasn't 
                                // able to explain.  Regardless, the Stack Overflow advice was to reserve enough to support 
                                // UTF-32.
                                ulong dataLength = lobLength * 4;
                                auto lobData = new char[dataLength];
                                ulong lobReadBytesLength = lobLength;
                                ulong lobReadCharactersLength = lobLength;
                                
                                OCILobRead2(
                                    serviceContext, 
                                    error, 
                                    locator, 
                                    &lobReadBytesLength, 
                                    &lobReadCharactersLength, 
                                    1, 
                                    lobData.ptr, 
                                    dataLength, 
                                    OCI_ONE_PIECE, 
                                    null, 
                                    null, 
                                    0, 
                                    0)
                                    .checkResult(error, &reportWarning);
                                
                                fields ~= OracleField(lobData[0 .. lobReadCharactersLength].to!string);
                                break;
                                
                            case DescriptorCategory.DateTime:
                                auto locator = value.getLocator!OCIDateTime;
                                
                                static char[255] dateAsText;
                                uint dateLength = dateAsText.length;
                                
                                OCIDateTimeToText(
                                    cast(void*)session, 
                                    error, 
                                    locator, 
                                    cast(const(ubyte)*)value.dateFormat.ptr, 
                                    cast(ubyte)value.dateFormat.length, 
                                    cast(ubyte)value.fractionalPrecision, 
                                    null, 
                                    cast(ulong)0, 
                                    &dateLength, 
                                    cast(ubyte*)dateAsText.ptr)
                                    .checkResult(error, &reportWarning);
                                
                                // Warning!  Fucking shit API ahead.
                                // 
                                // In my example, I had TIMESTAMP(3) and OCI_ATTR_SCALE returns 3 (so milliseconds).
                                // The documentation for OCIDateTimeGetTime on the last parameter says "fsec" with description 
                                // "The retrieved fractional second value".
                                // 
                                // This does not commit to any known units for the last parameter.  That sort of makes sense because this is 
                                // configurable.  Therefore I wrote the below to scale the result to the right units (I chose nanoseconds).
                                // 
                                //      auto nanoseconds = fractions * 10L ^^ (9 - scale);
                                //
                                // However, in testing this fails because the API always returns nanoseconds (for me).  So is that always the 
                                // case?  If so, then why not document the known units?  If not, how am I supposed to know what is really 
                                // returned if OCI_ATTR_SCALE can't be used?
                                
                                short year;
                                ubyte month;
                                ubyte day;
                                ubyte hour;
                                ubyte minute;
                                ubyte second;
                                uint  nanoseconds;
                                
                                OCIDateTimeGetDate(
                                    environment, 
                                    error,
                                    locator, 
                                    &year, 
                                    &month, 
                                    &day)
                                    .checkResult(error, &reportWarning);
                                OCIDateTimeGetTime(
                                    environment, 
                                    error,
                                    locator, 
                                    &hour,
                                    &minute, 
                                    &second, 
                                    &nanoseconds)
                                    .checkResult(error, &reportWarning);
                                
                                byte timeZoneOffsetHour;
                                byte timeZoneOffsetMinute;
                                
                                OCIDateTimeGetTimeZoneOffset(
                                    environment, 
                                    error,
                                    locator, 
                                    &timeZoneOffsetHour, 
                                    &timeZoneOffsetMinute);
                                
                                fields ~= OracleField(OracleDate(
                                            SysTime(DateTime(year, month, day, hour, minute, second), 
                                                    nsecs(nanoseconds), 
                                                    new immutable SimpleTimeZone(hours(timeZoneOffsetHour) + minutes(timeZoneOffsetMinute))), 
                                            dateAsText[0 .. dateLength].to!string));
                                break;
                                
                            case DescriptorCategory.Interval:
                                const locator = value.getLocator!OCIInterval;
                                
                                static char[255] intervalAsText;
                                size_t intervalLength = intervalAsText.length;
                                
                                OCIIntervalToText(
                                    cast(void*)session, 
                                    error, 
                                    locator, 
                                    0, 
                                    0, 
                                    cast(ubyte*)intervalAsText.ptr, 
                                    intervalAsText.length, 
                                    &intervalLength)
                                    .checkResult(error, &reportWarning);
                                
                                fields ~= OracleField(intervalAsText[0 .. intervalLength].to!string);
                                break;
                        }
                        
                        break;
                }
            }
            
            return fields;
        }
    }
    
    auto ExecuteSynchronous(ResultTuple)(string command, BindVariable[] bindVariables...) 
    if (isTuple!ResultTuple)
    {
        try
        {
            auto statement = new Statement;
            scope (exit) statement.free;
            
            if (statement.execute(command, 16, false, bindVariables) != Statement.Type.selectWithRows)
                return null;
            
            ResultTuple[] results;
            while (true)
            {
                auto record = statement.fetch;
                if (record.length == 0)
                    break;
                
                ResultTuple result;
                
                static foreach (fieldIndex, type; ResultTuple.Types)
                {
                    static if (is(type == string))
                        result[fieldIndex] = record[fieldIndex].tryMatch!(
                            (const NullField    _) { return "";    }, 
                            (const string   value) { return value; });
                        
                    else static if (isIntegral!type)
                        result[fieldIndex] = record[fieldIndex].tryMatch!(
                            (const NullField    _) { return type.init; }, 
                            (const OracleNumber n) { return n.to!type; });
                    else static if (is(TemplateArgsOf!type[0]))
                    {{
                        alias innerType = TemplateArgsOf!type[0];
                        
                        static assert (is(type == Nullable!innerType), "ExecuteSynchronous ResultTuple value " ~ type.stringof ~ " not yet supported.");
                        
                        static assert (isIntegral!innerType, "ExecuteSynchronous ResultTuple value " ~ type.stringof ~ " not yet supported.");
                        
                        result[fieldIndex] = record[fieldIndex].tryMatch!(
                            (const NullField    _) { return type.init;        }, 
                            (const OracleNumber n) { return type(n.to!innerType); });
                    }}
                    else
                        static assert(false, "ExecuteSynchronous ResultTuple value " ~ type.stringof ~ " not yet supported.");
                }
                
                results ~= result;
            }
            
            return results;
        }
        catch (OracleException exception)
        {
            if (exception.code == 1013) // ORA-01013: user requested cancel of current operation
                throw new InstructionCancelledException;
            
            throw exception;
        }
    }
    
    string ExecuteScalarSynchronous(string command, BindVariable[] bindVariables...) 
    {
        auto statement = new Statement;
        scope (exit) statement.free;
        
        if (statement.execute(command, 1, false, bindVariables) != Statement.Type.selectWithRows)
            return null;
        
        auto record = statement.fetch;
        if (record.length == 0)
            return null;
        
        return record[0].tryMatch!(
            (NullField  _) { return ""; }, 
            (string value) { return value; });
    }
    
    SqlError CreateSqlError(const string command, const string errorMessage, const int errorCode, const int scriptLine, const int errorLine, const int errorColumn, const bool isSilent)
    {
        auto sourceLines = command.splitLines;
        immutable(string)[] lines;
        
        // The source command might be huge.  Slice the command into a smaller 
        // window for display, just showing lines around the error.
        
        const startIndex = max(0, errorLine - 6);
        const endIndex   = min(sourceLines.intLength, errorLine + 6);
        sourceLines = sourceLines[startIndex .. endIndex];
        
        const windowStartLine = scriptLine + startIndex;
        const relativeErrorLine = errorLine - startIndex - 1;
        
        // How wide should the first column be to allow for all row numbers?
        const rowHeadersWidth = (windowStartLine + sourceLines.intLength).to!string.intLength;
        
        foreach (subLine, lineText; sourceLines)
            lines ~= (windowStartLine + subLine).to!string.rightJustify(rowHeadersWidth, '0') ~ ": " ~ lineText;
        
        return SqlError(lines, errorMessage, errorCode, windowStartLine + relativeErrorLine, relativeErrorLine, errorColumn, rowHeadersWidth + 2, isSilent);
    }
    
    void Execute(const string commandText, const int scriptLine, const bool isSilent, BindVariable[] bindVariables...)
    {
        if (!isConnected)
            throw new RecoverableException("No database connection.");
        
        // Apparently CRs cause a problem on a Unix box but not on a Windows box.
        // Strange, because I've sent CRs from VB.NET many times.
        auto command = 
                commandText.any!(c => c == cast(ubyte)'\r') ?
                    commandText.replace("\r\n", "\n") : 
                    commandText;
        
        auto stopWatch = StopWatch(AutoStart.yes);
        
        auto statement = new Statement;
        scope (exit) statement.free;
        
        try
        {
            auto fetchSize = 1;
            auto rowCount = 0;
            int statementType;
            
            try
            {
                if (statement.execute(command, 1, true, bindVariables) == Statement.Type.selectWithRows)
                {
                    if (!isSilent)
                        reply(statement.columns);
                    
                    while (true)
                    {
                        immutable record = statement.fetch;
                        if (record.length == 0)
                            break;
                        
                        rowCount++;
                        if (!isSilent)
                            reply(record);
                        
                        CheckCancellationRequested;
                        
                        auto timePerRow = (stopWatch.peek / rowCount).total!"nsecs";
                        int newFetchSize;
                        
                        if (timePerRow > 0)
                        {
                            enum quarterSecond = dur!"msecs"(250).total!"nsecs";
                            newFetchSize = cast(int)max(1, min(2048, quarterSecond / timePerRow));
                            
                            if (newFetchSize != fetchSize)
                            {
                                statement.setPreFetchSize(newFetchSize);
                                fetchSize = newFetchSize;
                            }
                        }
                    }
                }
                
                stopWatch.stop;
            }
            finally
            {
                if (isBulkDbmsOutputSupported)
                {
                    // Multi-line method.  Fast, but not supported on earlier versions.
                    auto linesParameter = new StringVarrayOutputBindVariable("p_lines_text");
                    scope (exit) GC.free(cast(void*)linesParameter);
                    
                    auto numberOfLinesParameter = new InputOutputBindVariable!int("p_number_of_lines");
                    scope (exit) GC.free(cast(void*)numberOfLinesParameter);
                    
                    while (true)
                    {
                        numberOfLinesParameter.result = 64;
                        
                        ExecuteSynchronous!(Tuple!(long, "Dummy"))(
                            "BEGIN DBMS_OUTPUT.GET_LINES(:p_lines_text, :p_number_of_lines); END;", 
                             linesParameter, 
                             numberOfLinesParameter);
                        
                        if (numberOfLinesParameter.result == 0)
                            break;
                        
                        linesParameter.processResult!report;
                    }
                }
                else
                {
                    // Single line method.  It's pretty slow, especially over a VPN.
                    auto textParameter = new InputOutputBindVariable!(string, 32767)("p_text");
                    scope (exit) GC.free(cast(void*)textParameter);
                    
                    auto statusParameter = new InputOutputBindVariable!int("p_status");
                    scope (exit) GC.free(cast(void*)statusParameter);
                    
                    while (true)
                    {
                        ExecuteSynchronous!(Tuple!(long, "Dummy"))(
                            "BEGIN DBMS_OUTPUT.GET_LINE(:p_text, :p_status); END;", 
                             textParameter, 
                             statusParameter);
                        
                        if (statusParameter.result == 1)
                            break;
                        
                        report(textParameter.result);
                    }
                }
            }
            
            auto commandType = statement.functionCode;
            if (commandType == Statement.FunctionCode.AlterSession)
                RefreshDefaultDateFormat;
            
            reply(()
            {
                SqlSuccess AffectedRowText(const string suffix, const bool isUpdate)()
                {
                    auto affectedRowCount = statement.affectedRows;
                    
                    if (affectedRowCount == 0)
                        return SqlSuccess(0, isUpdate, CommitState.Uncommitted, "No rows " ~ suffix ~ lineEnding, stopWatch.peek, isSilent);
                    else if (affectedRowCount == 1)
                        return SqlSuccess(1, isUpdate, CommitState.Uncommitted, "1 row " ~ suffix ~ lineEnding, stopWatch.peek, isSilent);
                    else
                        return SqlSuccess(affectedRowCount, isUpdate, CommitState.Uncommitted, format("%,d", affectedRowCount) ~ " rows " ~ suffix ~ lineEnding, stopWatch.peek, isSilent);
                }
                
                SqlSuccess CreatePLSQLText(const string type, const string prefix)()
                {
                    lastPlSqlObjectType = type;
                    lastPlSqlObjectName = ()
                    {
                        auto remainingCommand = "";
                        if (Interpreter.StartsWithCommandWord!("CREATE - - " ~ type, "CREATE OR REPLACE " ~ type)(command, remainingCommand))
                            return OracleNames.ParseName(Interpreter.ConsumeToken!(Interpreter.SplitBy.Complex)(remainingCommand));
                        
                        enum plSqlErrorSql = 
                            "SELECT MAX(object_name) KEEP (DENSE_RANK LAST ORDER BY last_ddl_time) AS name " ~ 
                            "  FROM user_objects                    " ~ 
                            " WHERE object_type = :p_type           ";
                        
                        auto lastObject = ExecuteSynchronous!(Tuple!(string, "Name"))
                           (plSqlErrorSql, 
                            createInputBinding("p_type", type));
                        
                        return OracleObjectName("", lastObject[0].Name, "", "");
                    }();
                    
                    enum plSqlErrorSql = 
                        "SELECT line,           \n" ~ 
                        "       position,       \n" ~ 
                        "       text,           \n" ~ 
                        "       message_number, \n" ~ 
                        "       attribute       \n" ~ 
                        "  FROM all_errors      \n" ~ 
                        " WHERE owner = NVL(:p_owner, :p_current_schema) \n" ~ 
                        "   AND name = :p_name                    \n" ~ 
                        "   AND type = :p_type                    \n" ~ 
                        " ORDER BY                                \n" ~ 
                        "       DECODE(attribute, 'ERROR', 1, 2), \n" ~ 
                        "       sequence                          \n";
                    
                    alias Result = Tuple!(int, "Line", int, "Column", string, "Error", int, "ErrorCode", string, "Attribute");
                    auto errors = ExecuteSynchronous!Result
                       (plSqlErrorSql, 
                        createInputBinding("p_owner", lastPlSqlObjectName.Schema), 
                        createInputBinding("p_name", lastPlSqlObjectName.ObjectName), 
                        createInputBinding("p_type", type), 
                        createInputBinding("p_current_schema", currentSchema));
                    
                    string description;
                    
                    if (errors.length == 0)
                    {
                        lastPlSqlError = SqlError();
                        description = prefix ~ " successfully." ~ lineEnding;
                    }
                    else
                    {
                        auto isErrorFound = false;
                        lastPlSqlError = SqlError();
                        
                        foreach (error; errors)
                            if (error.Attribute == "ERROR")
                            {
                                isErrorFound = true;
                                lastPlSqlError = CreateSqlError(command, error.Error, error.ErrorCode, scriptLine, error.Line, error.Column, isSilent);
                                break;
                            }
                        
                        if (isErrorFound)
                            description = prefix ~ " with compilation errors." ~ lineEnding;
                        else
                            description = prefix ~ " with compilation warnings." ~ lineEnding;
                    }
                    
                    return SqlSuccess(0, false, CommitState.Committed, description, stopWatch.peek, isSilent);
                }
                
                SqlSuccess Text(const CommitState knownCommitState = CommitState.Uncommitted)(const string description)
                {
                    CommitState implicitCommitState = knownCommitState;
                    
                    static if (knownCommitState == CommitState.Uncommitted)
                    {
                        if (statement.statementType == OCI_STMT_CREATE ||
                            statement.statementType == OCI_STMT_DROP   || 
                            statement.statementType == OCI_STMT_ALTER)
                            
                            implicitCommitState = CommitState.Committed;
                        else
                            implicitCommitState = CommitState.Uncommitted;
                    }
                    
                    return SqlSuccess(0, false, implicitCommitState, description ~ lineEnding, stopWatch.peek, isSilent);
                }
                
                switch (commandType)
                {
                    case Statement.FunctionCode.CreateTable:               return Text("Tabled created.");
                    case Statement.FunctionCode.SetRole:                   return Text("Role set.");
                    case Statement.FunctionCode.Insert:                    return AffectedRowText!("inserted.", true);
                    case Statement.FunctionCode.Select:                    return AffectedRowText!("selected.", false);
                    case Statement.FunctionCode.Update:                    return AffectedRowText!("updated.", true);
                    case Statement.FunctionCode.DropRole:                  return Text("Role dropped.");
                    case Statement.FunctionCode.DropView:                  return Text("View dropped.");
                    case Statement.FunctionCode.DropTable:                 return Text("Table dropped.");
                    case Statement.FunctionCode.Delete:                    return AffectedRowText!("deleted.", true);
                    case Statement.FunctionCode.CreateView:                return CreatePLSQLText!("VIEW", "View created");
                    case Statement.FunctionCode.DropUser:                  return Text("User dropped.");
                    case Statement.FunctionCode.CreateRole:                return Text("Role created.");
                    case Statement.FunctionCode.CreateSequence:            return Text("Sequence created.");
                    case Statement.FunctionCode.AlterSequence:             return Text("Sequence altered.");
                    case Statement.FunctionCode.DropSequence:              return Text("Sequence dropped.");
                    case Statement.FunctionCode.CreateSchema:              return Text("Schema Created.");
                    case Statement.FunctionCode.CreateCluster:             return Text("Cluster created.");
                    case Statement.FunctionCode.CreateUser:                return Text("User created.");
                    case Statement.FunctionCode.CreateIndex:               return Text("Index created.");
                    case Statement.FunctionCode.DropIndex:                 return Text("Index dropped.");
                    case Statement.FunctionCode.DropCluster:               return Text("Cluster dropped.");
                    case Statement.FunctionCode.ValidateIndex:             return Text("Index validated.");
                    case Statement.FunctionCode.CreateProcedure:           return CreatePLSQLText!("PROCEDURE", "Procedure created");
                    case Statement.FunctionCode.AlterProcedure:            return CreatePLSQLText!("PROCEDURE", "Procedure altered");
                    case Statement.FunctionCode.AlterTable:                return Text("Table altered.");
                    case Statement.FunctionCode.Explain:                   return Text("Explain succeeded.");
                    case Statement.FunctionCode.Grant:                     return Text("Grant succeeded.");
                    case Statement.FunctionCode.Revoke:                    return Text("Revoke succeeded.");
                    case Statement.FunctionCode.CreateSynonym:             return Text("Synonym created.");
                    case Statement.FunctionCode.DropSynonym:               return Text("Synonym dropped.");
                    case Statement.FunctionCode.AlterSystemSwitchlog:      return Text("System switch log altered.");
                    case Statement.FunctionCode.SetTransaction:            return Text("Transaction set.");
                    case Statement.FunctionCode.PlsqlExecute:              return Text("PL/SQL procedure successfully completed.");
                    case Statement.FunctionCode.Lock:                      return Text("Lock successful.");
                    case Statement.FunctionCode.Noop:                      return Text("No operation performed.");
                    case Statement.FunctionCode.Rename:                    return Text("Rename successful.");
                    case Statement.FunctionCode.Comment:                   return Text("Comment successful.");
                    case Statement.FunctionCode.Audit:                     return Text("Audit successful.");
                    case Statement.FunctionCode.NoAudit:                   return Text("No audit successful.");
                    case Statement.FunctionCode.AlterIndex:                return Text("Index altered.");
                    case Statement.FunctionCode.CreateExternalDatabaseLink:return Text("External database link created.");
                    case Statement.FunctionCode.DropExternaldatabaseLink:  return Text("External database link dropped.");
                    case Statement.FunctionCode.CreateDatabase:            return Text("Database created.");
                    case Statement.FunctionCode.AlterDatabase:             return Text("Database altered.");
                    case Statement.FunctionCode.CreateRollbackSegment:     return Text("Rollback segment created.");
                    case Statement.FunctionCode.AlterRollbackSegment:      return Text("Rollback segment altered.");
                    case Statement.FunctionCode.DropRollbackSegment:       return Text("Rollback segment dropped.");
                    case Statement.FunctionCode.CreateTablespace:          return Text("Tablespace created.");
                    case Statement.FunctionCode.AlterTablespace:           return Text("Tablespace altered.");
                    case Statement.FunctionCode.DropTablespace:            return Text("Tablespace dropped.");
                    case Statement.FunctionCode.AlterSession:              return Text("Session altered.");
                    case Statement.FunctionCode.AlterUser:                 return Text("User altered.");
                    case Statement.FunctionCode.CommitWork:                return Text!(CommitState.Committed)("Commit complete.");
                    case Statement.FunctionCode.Rollback:                  return Text!(CommitState.RolledBack)("Rollback complete.");
                    case Statement.FunctionCode.Savepoint:                 return Text("Savepoint created.");
                    case Statement.FunctionCode.CreateControlFile:         return Text("Control file created.");
                    case Statement.FunctionCode.AlterTracing:              return Text("Tracing altered.");
                    case Statement.FunctionCode.CreateTrigger:             return CreatePLSQLText!("TRIGGER", "Trigger created");
                    case Statement.FunctionCode.AlterTrigger:              return CreatePLSQLText!("TRIGGER", "Trigger altered");
                    case Statement.FunctionCode.DropTrigger:               return Text("Trigger dropped.");
                    case Statement.FunctionCode.AnalyzeTable:              return Text("Table analyzed.");
                    case Statement.FunctionCode.AnalyzeIndex:              return Text("Index analyzed.");
                    case Statement.FunctionCode.AnalyzeCluster:            return Text("Cluster analyzed.");
                    case Statement.FunctionCode.CreateProfile:             return Text("Profile created.");
                    case Statement.FunctionCode.DropProfile:               return Text("Profile dropped.");
                    case Statement.FunctionCode.AlterProfile:              return Text("Profile altered.");
                    case Statement.FunctionCode.DropProcedure:             return Text("Procedure dropped.");
                    case Statement.FunctionCode.AlterResourceCost:         return Text("Resource cost altered.");
                    case Statement.FunctionCode.CreateSnapshotLog:         return Text("Snapshot log created.");
                    case Statement.FunctionCode.AlterSnapshotLog:          return Text("Snapshot log altered.");
                    case Statement.FunctionCode.DropSnapshotLog:           return Text("Snapshot log dropped.");
                    case Statement.FunctionCode.DropSummary:               return Text("Summary dropped.");
                    case Statement.FunctionCode.CreateSnapshot:            return Text("Snapshot created.");
                    case Statement.FunctionCode.AlterSnapshot:             return Text("Snapshot altered.");
                    case Statement.FunctionCode.DropSnapshot:              return Text("Snapshot dopped.");
                    case Statement.FunctionCode.CreateType:                return CreatePLSQLText!("TYPE", "Type created");
                    case Statement.FunctionCode.DropType:                  return Text("Type dropped.");
                    case Statement.FunctionCode.AlterRole:                 return Text("Role altered.");
                    case Statement.FunctionCode.AlterType:                 return CreatePLSQLText!("TYPE", "Type altered");
                    case Statement.FunctionCode.CreateTypeBody:            return CreatePLSQLText!("TYPE BODY", "Type body created");
                    case Statement.FunctionCode.AlterTypeBody:             return CreatePLSQLText!("TYPE BODY", "Type body altered");
                    case Statement.FunctionCode.DropTypeBody:              return Text("Type body dropped.");
                    case Statement.FunctionCode.DropLibrary:               return Text("Library dropped.");
                    case Statement.FunctionCode.TruncateTable:             return Text("Table truncated.");
                    case Statement.FunctionCode.TruncateCluster:           return Text("Cluster truncated.");
                    case Statement.FunctionCode.CreateBitmapfile:          return Text("Bitmap file created.");
                    case Statement.FunctionCode.AlterView:                 return CreatePLSQLText!("VIEW", "View altered");
                    case Statement.FunctionCode.DropBitmapfile:            return Text("Bitmap file dropped.");
                    case Statement.FunctionCode.SetConstraints:            return Text("Constraints set.");
                    case Statement.FunctionCode.CreateFunction:            return CreatePLSQLText!("FUNCTION", "Function created");
                    case Statement.FunctionCode.AlterFunction:             return CreatePLSQLText!("FUNCTION", "Function altered");
                    case Statement.FunctionCode.DropFunction:              return Text("Function dropped.");
                    case Statement.FunctionCode.CreatePackage:             return CreatePLSQLText!("PACKAGE", "Package created");
                    case Statement.FunctionCode.AlterPackage:              return CreatePLSQLText!("PACKAGE", "Package altered");
                    case Statement.FunctionCode.DropPackage:               return Text("Package dropped.");
                    case Statement.FunctionCode.CreatePackageBody:         return CreatePLSQLText!("PACKAGE BODY", "Package body created");
                    case Statement.FunctionCode.AlterPackageBody:          return CreatePLSQLText!("PACKAGE BODY", "Package body altered");
                    case Statement.FunctionCode.DropPackageBody:           return Text("Package body dropped.");
                    case Statement.FunctionCode.CreateDirectory:           return Text("Directory created.");
                    case Statement.FunctionCode.DropDirectory:             return Text("Directory dropped.");
                    case Statement.FunctionCode.CreateLibrary:             return CreatePLSQLText!("LIBRARY", "Library created");
                    case Statement.FunctionCode.CreateJava:                return CreatePLSQLText!("JAVA SOURCE", "Java created");
                    case Statement.FunctionCode.AlterJava:                 return CreatePLSQLText!("JAVA SOURCE", "Java altered");
                    case Statement.FunctionCode.DropJava:                  return Text("Java dropped.");
                    case Statement.FunctionCode.CreateOperator:            return Text("Operator created.");
                    case Statement.FunctionCode.CreateIndextype:           return Text("Index type created.");
                    case Statement.FunctionCode.DropIndextype:             return Text("Index type dropped.");
                    case Statement.FunctionCode.AlterIndextype:            return Text("Index type altered.");
                    case Statement.FunctionCode.DropOperator:              return Text("Operator dropped.");
                    case Statement.FunctionCode.AssociateStatistics:       return Text("Statistics associated.");
                    case Statement.FunctionCode.DisassociateStatistics:    return Text("Statistics disassociated.");
                    case Statement.FunctionCode.CallMethod:                return Text("Method called.");
                    case Statement.FunctionCode.CreateSummary:             return Text("Summary created.");
                    case Statement.FunctionCode.AlterSummary:              return Text("Summary altered.");
                    case Statement.FunctionCode.CreateDimension:           return CreatePLSQLText!("DIMENSION", "Dimension created");
                    case Statement.FunctionCode.AlterDimension:            return CreatePLSQLText!("DIMENSION", "Dimension altered");
                    case Statement.FunctionCode.DropDimension:             return Text("Dimension dropped.");
                    case Statement.FunctionCode.CreateContext:             return Text("Context created.");
                    case Statement.FunctionCode.DropContext:               return Text("Context dropped.");
                    case Statement.FunctionCode.AlterOutline:              return Text("Outline altered.");
                    case Statement.FunctionCode.CreateOutline:             return Text("Outline created.");
                    case Statement.FunctionCode.DropOutline:               return Text("Outline dropped.");
                    case Statement.FunctionCode.UpdateIndexes:             return Text("Indexes updated.");
                    case Statement.FunctionCode.AlterOperator:             return Text("Operator altered.");
                    case Statement.FunctionCode.CreateSpfile:              return Text("SP file created.");
                    case Statement.FunctionCode.CreatePfile:               return Text("P file created.");
                    case Statement.FunctionCode.Merge:                     return AffectedRowText!("merged.", true);
                    case Statement.FunctionCode.PasswordChange:            return Text("Password changed.");
                    case Statement.FunctionCode.AlterSynonym:              return Text("Synonym altered.");
                    case Statement.FunctionCode.AlterDiskgroup:            return Text("Disk group altered.");
                    case Statement.FunctionCode.CreateDiskgroup:           return Text("Disk group created.");
                    case Statement.FunctionCode.DropDiskgroup:             return Text("Disk group dropped.");
                    case Statement.FunctionCode.PurgeRecyclebin:           return Text("Recycle bin purged.");
                    case Statement.FunctionCode.PurgeDbaRecyclebin:        return Text("DBA recycle bin purged.");
                    case Statement.FunctionCode.PurgeTablespace:           return Text("Tablespace purged.");
                    case Statement.FunctionCode.PurgeTable:                return Text("Table purged.");
                    case Statement.FunctionCode.PurgeIndex:                return Text("Index purged.");
                    case Statement.FunctionCode.UndropObject:              return Text("Object undropped.");
                    case Statement.FunctionCode.DropDatabase:              return Text("Database dropped.");
                    case Statement.FunctionCode.FlashbackDatabase:         return Text("Database flashback successful.");
                    case Statement.FunctionCode.FlashbackTable:            return Text("Table flashback successful.");
                    case Statement.FunctionCode.CreateRestorePoint:        return Text("Restore point created.");
                    case Statement.FunctionCode.DropRestorePoint:          return Text("Restore point dropped.");
                    case Statement.FunctionCode.ProxyAuthenticationOnly:   return Text("Proxy authentication only successful.");
                    case Statement.FunctionCode.DeclareRewriteEquivalence: return Text("Rewrite equivalence declared.");
                    case Statement.FunctionCode.AlterRewriteEquivalence:   return Text("Rewrite equivalence altered.");
                    case Statement.FunctionCode.DropRewriteEquivalence:    return Text("Rewrite equivalence dropped.");
                    case Statement.FunctionCode.CreateEdition:             return Text("Edition created.");
                    case Statement.FunctionCode.AlterEdition:              return Text("Edition altered.");
                    case Statement.FunctionCode.DropEdition:               return Text("Edition dropped.");
                    case Statement.FunctionCode.DropAssembly:              return Text("Assembly dropped.");
                    case Statement.FunctionCode.CreateAssembly:            return Text("Assembly created.");
                    case Statement.FunctionCode.AlterAssembly:             return Text("Assembly altered.");
                    case Statement.FunctionCode.CreateFlashbackArchive:    return Text("Flashback archive created.");
                    case Statement.FunctionCode.AlterFlashbackArchive:     return Text("Flashback archive altered.");
                    case Statement.FunctionCode.DropFlashbackArchive:      return Text("Flashback archive dropped.");
                    case Statement.FunctionCode.DebugConnect:              return Text("Debug connected.");
                    case Statement.FunctionCode.DebugProcedure:            return Text("Debug procedure successful.");
                    case Statement.FunctionCode.AlterDatabaseLink:         return Text("Database link altered.");
                    case Statement.FunctionCode.CreatePluggableDatabase:   return Text("Pluggable database created.");
                    case Statement.FunctionCode.AlterPluggableDatabase:    return Text("Pluggable database altered.");
                    case Statement.FunctionCode.DropPluggableDatabase:     return Text("Pluggable database dropped.");
                    case Statement.FunctionCode.CreateAuditPolicy:         return Text("Audit policy created.");
                    case Statement.FunctionCode.AlterAuditPolicy:          return Text("Audit policy altered.");
                    case Statement.FunctionCode.DropAuditPolicy:           return Text("Audit policy dropped.");
                    case Statement.FunctionCode.CodeBasedGrant:            return Text("Code based grant successful.");
                    case Statement.FunctionCode.CodeBasedRevoke:           return Text("Code based revoke successful.");
                    case Statement.FunctionCode.CreateLockdownProfile:     return Text("Lockdown profile created.");
                    case Statement.FunctionCode.DropLockdownProfile:       return Text("Lockdown profile dropped.");
                    case Statement.FunctionCode.AlterLockdownProfile:      return Text("Lockdown profile altered.");
                    case Statement.FunctionCode.TranslateSql:              return Text("SQL Translated.");
                    case Statement.FunctionCode.AdministerKeyManagement:   return Text("Administer key management successful.");
                    case Statement.FunctionCode.CreateMaterializedZonemap: return Text("Materialized zone map created.");
                    case Statement.FunctionCode.AlterMaterializedZonemap:  return Text("Materialized zone map altered.");
                    case Statement.FunctionCode.DropMaterializedZonemap:   return Text("Materialized zone map dropped.");
                    case Statement.FunctionCode.DropMiningModel:           return Text("Mining model dropped.");
                    case Statement.FunctionCode.CreateAttributeDimension:  return Text("Attribute dimension created.");
                    case Statement.FunctionCode.AlterAttributeDimension:   return Text("Attribute dimension altered.");
                    case Statement.FunctionCode.DropAttributeDimension:    return Text("Attribute dimension dropped.");
                    case Statement.FunctionCode.CreateHierarchy:           return Text("Hierarchy created.");
                    case Statement.FunctionCode.AlterHierarchy:            return Text("Hierarchy altered.");
                    case Statement.FunctionCode.DropHierarchy:             return Text("Hierarchy dropped.");
                    case Statement.FunctionCode.CreateAnalyticView:        return Text("Analytic view created.");
                    case Statement.FunctionCode.AlterAnalyticView:         return Text("Analytic view altered.");
                    case Statement.FunctionCode.DropAnalyticView:          return Text("Analytic view dropped.");
                    case Statement.FunctionCode.AlterPublicDatabaseLink:   return Text("Public database link altered.");
                    default:                                               return AffectedRowText!("affected.", true);
                }
            }());
        }
        catch (OracleException exception)
        {
            if (exception.code == 1013) // ORA-01013: user requested cancel of current operation.
                throw new InstructionCancelledException;
            
            immutable errorPosition = max(0, min(command.intLength - 1, statement.errorOffset));
            int errorLineNumber = 1;
            auto errorLineStartPosition = 0;
            auto position = 0;
            while (position < errorPosition)
            {
                auto character = command[position];
                position++;
                
                if (character == '\r')
                {
                    if (position < command.length && command[position] == '\n')
                        position++;
                    
                    errorLineNumber++;
                    errorLineStartPosition = position;
                }
                else if (character == '\n')
                {
                    errorLineNumber++;
                    errorLineStartPosition = position;
                }
            }
            
            immutable int errorColumn = errorPosition - errorLineStartPosition + 1;
            reply(CreateSqlError(command, exception.msg, exception.code, scriptLine, errorLineNumber, errorColumn, isSilent));
            return;
        }
    }
    
    void CheckCancellationRequested()
    { 
        receiveTimeout(seconds(-1), 
            (Tid senderThreadId, Instruction instruction)
                {
                    if (senderThreadId != ownerThreadId)
                        throw new NonRecoverableException("Oracle Worker received unexpected message from " ~ senderThreadId.to!string ~ ".");
                    
                    auto instructionType = instruction.match!(
                        (SimpleInstruction simpleInstruction)
                        {
                            if (simpleInstruction == SimpleInstruction.Cancel)
                                throw new InstructionCancelledException;
                        
                            if (simpleInstruction == SimpleInstruction.Kill)
                                throw new WorkerKilledException;            

                            return simpleInstruction.to!string;
                        }, 
                        (ExecuteInstruction _) => "ExecuteInstruction", 
                        (ConnectionDetails  _) => "ConnectionDetails", 
                        (ObjectInstruction  _) => "ObjectInstruction", 
                    );
                    
                    throw new NonRecoverableException("Oracle Worker received unexpected message type " ~ instructionType ~ ".");
                }
            );
    }
}
