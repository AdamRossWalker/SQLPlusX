module database;

import std.array : replicate;
import std.concurrency : LinkTerminated, MailboxFull, OnCrowding, OwnerTerminated, receiveTimeout, send, setMaxMailboxSize, spawnLinked, thisTid, Tid;
import std.conv : to;
import std.datetime;
import std.datetime.stopwatch : StopWatch, AutoStart;
import std.sumtype : match, SumType;
import std.string : fromStringz, indexOf, toUpper, lastIndexOf, endsWith;
import std.typecons : Flag, Yes, No, Tuple, BitFlags;
import std.variant : Variant;

import program;
import oracle;

alias OracleNumber = oracle.OracleNumber;

public enum CommitState
{
    Uncommitted, 
    Committed, 
    RolledBack
}

struct NullField { }

alias OracleDate = Tuple!(SysTime, "Value", string, "Text");
alias OracleColumns = immutable(OracleColumn)[];
alias OracleField = SumType!(NullField, string, OracleNumber, OracleDate);
alias OracleRecord = immutable(OracleField)[];
alias SqlError = Tuple!(immutable(string)[], "CommandLines", string, "Error", int, "ErrorCode", int, "AbsoluteErrorLine", int, "RelativeErrorLine", int, "ErrorColumn", int, "RowHeadersWidth", bool, "IsSilent");
alias SqlSuccess = Tuple!(int, "AffectedRowCount", bool, "WasUpdate", CommitState, "WasCommitted", string, "Description", Duration, "Duration", bool, "IsSilent");

public struct ObjectInstruction
{
    enum Types { Describe, ShowSource, ShowErrors}
    Types type;
    OracleObjectName name;
    string variant;
}

enum StatusFlag
{   
    None, 
    isBulkDbmsOutputSupported       = 1 << 1, 
    isProcedureTypeInDataDictionary = 1 << 2, 
}

alias StatusFlags = immutable BitFlags!StatusFlag;

enum SimpleInstruction { Disconnect, Cancel, Kill }
alias ExecuteInstruction = Tuple!(string, "Command", int, "LineNumber", bool, "IsSilent");
alias Instruction = SumType!(SimpleInstruction, ExecuteInstruction, ConnectionDetails, ObjectInstruction);

enum MessageResultType { Information, Warning, NlsDateFormat, Connected, Disconnected, Cancelled, PasswordExpired, Failure, ThreadFailure }
alias MessageResult = Tuple!(MessageResultType, "Type", string, "Message", bool, "IsSyntaxHighlightable");
alias InstructionResult = SumType!(MessageResult, OracleColumns, OracleRecord, SqlSuccess, SqlError, StatusFlags);

public struct ConnectionDetails
{
    enum Types {Normal, SysDba, SysOper}
    
    string username;
    string password;
    string newPassword;
    string host;
    Types type = Types.Normal;
    public bool isSilent = false;
    
    this(string username, string host, string password, Types type = Types.Normal) @nogc nothrow
    {
        this.username = username;
        this.host     = host;
        this.password = password;
        this.type     = type;
    }
    
    this(string connectionString)
    {
        enum sysDba  = " AS SYSDBA";
        enum sysOper = " AS SYSOPER";
        
        if (connectionString.toUpper.endsWith(sysDba))
        {
            type = Types.SysDba;
            connectionString = connectionString[0 .. $ - sysDba.length];
        }
        else if (connectionString.toUpper.endsWith(sysOper))
        {
            type = Types.SysOper;
            connectionString = connectionString[0 .. $ - sysOper.length];
        }
        
        immutable slashPosition = connectionString.indexOf('/');
        immutable atPosition = connectionString.lastIndexOf('@');
        
        if (slashPosition > 0)
        {
            if (atPosition > slashPosition)
            {
                username = connectionString[0 .. slashPosition];
                password = connectionString[slashPosition + 1 .. atPosition];
                host     = connectionString[atPosition + 1 .. $];
            }
            else
            {
                username = connectionString[0 .. slashPosition];
                password = connectionString[slashPosition + 1 .. $];
                host     = "";
            }
        }
        else if (atPosition > 0)
        {
            username = connectionString[0 .. atPosition];
            password = "";
            host     = connectionString[atPosition + 1 .. $];
        }
        else
        {
            username = "";
            password = "";
            host     = connectionString;
        }
        
        if (username.length > 0 && username[0] != '\"')
            username = username.toUpper;
    }
}

public final class DatabaseManager
{
    private Tid workerThreadId;
    
    private bool isConnected = false;
    public bool IsConnected() const @nogc nothrow { return isConnected; }
    
    private bool isConnectInProgress = false;
    public bool IsConnectInProgress() const @nogc nothrow { return isConnectInProgress; }
    
    private bool isCommandInProgress = false;
    public bool IsCommandInProgress() const @nogc nothrow { return isCommandInProgress; }
    
    private bool isCancellationRequested = false;
    public bool IsCancellationRequested() const @nogc nothrow { return isCancellationRequested; }
    
    private auto uncommittedChangeCount = 0;
    public auto UncommittedChangeCount() const @nogc nothrow { return uncommittedChangeCount; }
    
    private StopWatch stopWatch;
    
    auto isBulkDbmsOutputSupported       = false;
    auto isProcedureTypeInDataDictionary = false;
    
    private void commandStarting()
    {
        isCommandInProgress = true;
        stopWatch = StopWatch(AutoStart.yes);
    }
    
    private void commandEnded()
    {
        isCommandInProgress = false;
        stopWatch.stop;
    }
    
    public StringReference CurrentActivityDescription() @nogc nothrow
    {
        static char[64] result;
        
        immutable message = 
            isCancellationRequested ? "Cancelling... " : 
            isConnectInProgress     ? "Connecting... " : 
            isCommandInProgress     ? "Executing... "  : "";
        
        if (message.length == 0)
            return null;
        
        result[0 .. message.length] = message;
        DurationToPrettyStringEmplace(stopWatch.peek, result[message.length .. message.length + 8]);
        
        return result[0 .. message.length + 8];
    }
    
    private SysTime futureIdleExpirationTime;
    
    public void KeepConnectionAliveIfNecessary()
    {
        if (Clock.currTime < futureIdleExpirationTime || isCommandInProgress || isConnectInProgress || isCancellationRequested || !IsConnected)
            return;
        
        Execute("SELECT 1 FROM dual WHERE 1 = 2", 0, true);
    }
    
    public ConnectionDetails connectionDetails;
    
    static void GlobalInitialisation()
    {
        thisTid.setMaxMailboxSize(8192, OnCrowding.block);
        ThreadLocalInitialisation();
    }
    
    static void GlobalFinalisation()
    {
        ThreadLocalFinalisation;
    }
    
    alias ResultHandlerType = void delegate(InstructionResult);
    private ResultHandlerType resultHandler;
    
    private void ProcessResult(InstructionResult result)
    {
        void finalise()
        {
            commandEnded;
            isConnectInProgress = false;
            isCancellationRequested = false;
            futureIdleExpirationTime = Clock.currTime + dur!"minutes"(20);
        }
        
        result.match!(
            (OracleRecord     record) { }, 
            (OracleColumns   columns) { }, 
            (SqlError          error) => finalise, 
            (StatusFlags statusFlags) 
            {
                isBulkDbmsOutputSupported       = statusFlags.isBulkDbmsOutputSupported;
                isProcedureTypeInDataDictionary = statusFlags.isProcedureTypeInDataDictionary;
            }, 
            (MessageResult message) 
            { 
                scope(exit)
                    if (message.Type != MessageResultType.Information && 
                        message.Type != MessageResultType.Warning && 
                        message.Type != MessageResultType.NlsDateFormat)
                        finalise;
                
                if (message.Type == MessageResultType.Connected)
                {
                    isConnected = true;
                    
                    if (connectionDetails.newPassword.length > 0)
                    {
                        connectionDetails.password = connectionDetails.newPassword;
                        connectionDetails.newPassword = "";
                    }
                }
                else if (message.Type == MessageResultType.Disconnected)
                    isConnected = false;
                else if (message.Type == MessageResultType.ThreadFailure)
                    throw new NonRecoverableException(message.Message);
            }, 
            (SqlSuccess success)
            {
                scope(exit) finalise;
                
                if (success.WasCommitted == CommitState.Committed || 
                    success.WasCommitted == CommitState.RolledBack)
                    
                    uncommittedChangeCount = 0;
                else if (success.WasUpdate)
                    uncommittedChangeCount += success.AffectedRowCount;
                
                // If the database receives the cancellation before the worker thread, 
                // then the command sometimes looks like it completed successfully with 
                // misleading results.  
                // 
                // In such a case, throw away the success result and notify cancellation 
                // instead.
                if (!success.WasUpdate && isCancellationRequested)
                    result = MessageResult(MessageResultType.Cancelled, "", false);
            },
        );
        
        resultHandler(result);
    }
    
    this(ResultHandlerType resultHandler)
    {
        this.resultHandler = resultHandler;
        workerThreadId = spawnLinked(&Worker.Start, thisTid);
        
        workerThreadId.setMaxMailboxSize(3, OnCrowding.throwException);
        // Only three are expected (one for an actual command, one for a cancellation 
        // of that command, and one for an OwnerTerminated exception or similar).  
        
        // However, in the rare case that the worker thread is blocked and OCIBreak 
        // can't or won't interrupt, cancel messages may throw here.
        
        managersForAllWorkerThreads[workerThreadId] = this;
    }
    
    private static DatabaseManager[Tid] managersForAllWorkerThreads;
    
    // The main thread will receive messages from all worker threads, 
    // so this needs to be a thread level check that sends the results 
    // to each registered handler.
    static void ProcessResultsAcrossAllThreads()
    {
        while (true)
        {
            InstructionResult result;
            Tid senderThreadId;
            
            if (!receiveTimeout(seconds(-1), 
                    (Tid innerSenderThreadId, InstructionResult innerResult)
                    {
                        senderThreadId = innerSenderThreadId;
                        result = innerResult;
                    }, 
                    
                    (Variant unknownMessage)
                    {
                        throw new RecoverableException("Background Manager received unexpected message of type " ~ unknownMessage.type.toString ~ ".");
                    }))
                return;
            
            auto managerRef = senderThreadId in managersForAllWorkerThreads;
            if (managerRef is null)
                throw new RecoverableException("Background Manager received message from unexpected sender " ~ senderThreadId.to!string ~ ".");
            
            auto manager = *managerRef;
            
            manager.ProcessResult(result);
        }
    }
    
    static void ClearAllMessages()
    {
        while (true)
        {
            try
            {
                if (!receiveTimeout(msecs(500), (Variant message) { }))
                    return;
            }
            catch (OwnerTerminated) { }
            catch (LinkTerminated) { }
        }
    }
    
    private void request(T)(T instruction)
    { 
        send(workerThreadId, thisTid, Instruction(instruction));
    }
    
    void Connect(Flag!"isPrimaryThread" isPrimaryThread = Yes.isPrimaryThread)(const ConnectionDetails connectionDetails)
    {
        this.connectionDetails = connectionDetails;
        
        static if (isPrimaryThread)
        {
            auto connectingText = "Connecting to " ~ connectionDetails.host;
            Program.Screen.SetTitle(connectingText);
            Program.Buffer.AddText(connectingText);
        }
        
        request(connectionDetails);
        
        commandStarting;
        isConnectInProgress = true;
    }
    
    void Disconnect()
    {
        request(SimpleInstruction.Disconnect);
        commandStarting;
    }
    
    void Execute(string command, int lineNumber, bool isSilent = false)
    {
        request(ExecuteInstruction(command, lineNumber, isSilent));
        commandStarting;
    }
    
    void Describe(OracleObjectName objectName)
    {
        request(ObjectInstruction(ObjectInstruction.Types.Describe, objectName, ""));
        commandStarting;
    }
    
    void ShowSource(OracleObjectName objectName)
    {
        request(ObjectInstruction(ObjectInstruction.Types.ShowSource, objectName, ""));
        commandStarting;
    }
    
    void ShowErrors(OracleObjectName objectName, string variant)
    {
        request(ObjectInstruction(ObjectInstruction.Types.ShowErrors, objectName, variant));
        commandStarting;
    }
    
    void Cancel()
    {
        if (!isCommandInProgress)
            return;
        
        if (!CrossThreadCancellation.CancelFromMainThread(workerThreadId))
        {
            Program.Buffer.AddText(isConnectInProgress ?
                 "Cannot cancel a connection attempt; it must time out...\n" : 
                 "Cannot issue cancellation to the worker thread.\n");
            return;
        }
        
        // Restart the timer only on the first cancellation request.
        if (!isCancellationRequested)
        {
            commandStarting;
            isCancellationRequested = true;
        }
        
        // In the rare case that the worker thread is blocked and OCIBreak 
        // can't or won't interrupt, cancel messages may throw here.
        // Ignore in case someone holds Esc down in frustration.  There's 
        // nothing I can do, sorry user.
        try
            request(SimpleInstruction.Cancel);
        catch (MailboxFull) { }
    }
    
    void Kill()
    {
        request(SimpleInstruction.Kill);
    }
}

struct OracleObjectName
{
    string Schema;
    string ObjectName;
    string SubName;
    string DatabaseLinkName;
}

public abstract final class OracleNames
{
    public static string RemoveQuotes(bool upperCaseIfNotQuoted = true)(string source) pure
    {
        if (source.length > 1 && 
            source[0]     == '\"' && 
            source[$ - 1] == '\"')
            return source[1 .. $ - 1];
        
        static if (upperCaseIfNotQuoted)
            return source.toUpper;
        else
            return source;
    }
    
    public static enum ParseQuotes { Keep, Remove } 
    
    public static OracleObjectName ParseName(ParseQuotes parseQuotes = ParseQuotes.Remove)(string name) pure
    {
        string schema       = "";
        string objectName   = name;
        string subName      = "";
        string databaseLink = "";
        
        // TODO: this won't work on names like: 
        //     table@"tricksy@_db_link"
        //     "tricksy.schema".table
        
        auto atPosition = objectName.lastIndexOf('@');
        if (atPosition >= 0)
        {
            databaseLink = objectName[atPosition + 1 .. $];
            objectName   = objectName[0 .. atPosition];
        }
        
        auto dotPosition = objectName.indexOf('.');
        if (dotPosition >= 0)
        {
            schema     = objectName[0 .. dotPosition];
            objectName = objectName[dotPosition + 1 .. $];
            
            dotPosition = objectName.indexOf('.');
            if (dotPosition >= 0)
            {
                subName    = objectName[dotPosition + 1 .. $];
                objectName = objectName[0 .. dotPosition];
            }
        }
        
        static if (parseQuotes == ParseQuotes.Remove)
            return OracleObjectName(
                RemoveQuotes(schema), 
                RemoveQuotes(objectName), 
                RemoveQuotes(subName), 
                RemoveQuotes(databaseLink));
        else
            return OracleObjectName(
                schema, 
                objectName, 
                subName, 
                databaseLink);
    }
    
    unittest
    {
        void Check(
            string sourceName, 
            string schema, 
            string objectName, 
            string subName, 
            string databaseLinkName)
        {
            auto oracleName = ParseName(sourceName);
            assert(oracleName.Schema           == schema,           sourceName ~ " Schema expected \""           ~ schema           ~ "\" decoded \"" ~ oracleName.Schema           ~ "\"");
            assert(oracleName.ObjectName       == objectName,       sourceName ~ " ObjectName expected \""       ~ objectName       ~ "\" decoded \"" ~ oracleName.ObjectName       ~ "\"");
            assert(oracleName.SubName          == subName,          sourceName ~ " SubName expected \""          ~ subName          ~ "\" decoded \"" ~ oracleName.SubName          ~ "\"");
            assert(oracleName.DatabaseLinkName == databaseLinkName, sourceName ~ " DatabaseLinkName expected \"" ~ databaseLinkName ~ "\" decoded \"" ~ oracleName.DatabaseLinkName ~ "\"");
        }
        
        Check("table_name", 
              "", 
              "TABLE_NAME", 
              "", 
              "");
        
        Check("schema.table_name", 
              "SCHEMA", 
              "TABLE_NAME", 
              "", 
              "");
        
        Check("schema.table_name@db_link_name", 
              "SCHEMA", 
              "TABLE_NAME", 
              "", 
              "DB_LINK_NAME");
        
        Check("schema.table_name.field_name@db_link_name", 
              "SCHEMA", 
              "TABLE_NAME", 
              "FIELD_NAME", 
              "DB_LINK_NAME");
        
        Check("schema.table_name.field_name", 
              "SCHEMA", 
              "TABLE_NAME", 
              "FIELD_NAME", 
              "");
        
        Check("table_name@db_link_name", 
              "", 
              "TABLE_NAME", 
              "", 
              "DB_LINK_NAME");
    }
}


public class OracleColumn
{
    static enum Types
    {
        Unsupported, 
        String, 
        Number, 
        DateTime
    }
    
    private immutable string name;
    public immutable string Name() pure @nogc nothrow { return name; }
    
    private immutable Types type;
    public immutable Types Type() pure @nogc nothrow { return type; }
    
    private immutable int maxSize;
    public immutable int MaxSize() pure  @nogc nothrow { return maxSize; }
    
    private immutable string defaultFormat;
    public immutable string DefaultFormat() pure @nogc nothrow { return defaultFormat; }
    
    public void Free() const
    {
        import core.memory : GC;
        GC.free(GC.addrOf(cast(void*)name.ptr));
        GC.free(GC.addrOf(cast(void*)this));
    }
    
    public immutable this(
        immutable string name, 
        immutable Types type, 
        immutable int maxSize, 
        immutable int precision, 
        immutable int scale)
    {
        this.name = name;
        this.type = type;
        this.maxSize = maxSize;
        this.defaultFormat = ()
        {
            if (precision == 0 || scale == -127 || scale >= precision)
                return "TM9";
            
            if (scale <= 0)
                return "FM" ~ replicate("9", precision);
            
            return "FM" ~ replicate("9", precision - scale) ~ "D" ~ replicate("0", scale);
        }();
    }
}
