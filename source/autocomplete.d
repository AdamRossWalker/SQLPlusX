module autocomplete;

import std.algorithm : canFind, filter, min, max, splitter, startsWith, endsWith, uniq, sort;
import std.array : array;
import std.conv : to;
import std.range : chain, padRight;
import std.string : toUpper, toLower, strip, lastIndexOf;
import std.sumtype : match, tryMatch;
import std.traits : hasUDA, getUDAs, getSymbolsByUDA;
import std.typecons : No;
import std.uni : isUpper, isLower;
import std.utf : byDchar;

import program;
import utf8_slice;

public final class AutoCompleteManager
{
    private final class CommandWords
    {
        CommandWords[string] Words;
        CommandWords[string] Aliases;
        immutable char Separator;
        
        this (const char separator = ' ')
        {
            Separator = separator;
        }
        
        void AddWord(string childWord, CommandWords childWords = null)
        {
            Words[childWord] = childWords;
        }
        
        void RemoveWord(string childWord)
        {
            Words.remove(childWord);
        }
        
        void AddAlias(string subWord, string fullWord)
        {
            Aliases[subWord] = Words[fullWord];
        }
        
        CommandWords RequireLookupFor(string childWord, char separator = ' ')
        {
            auto commandWords = Words.require(childWord, new CommandWords(separator));
            
            if (commandWords is null)
            {
                commandWords = new CommandWords(separator);
                Words[childWord] = commandWords;
            }
            
            return commandWords;
        }
    }
    
    private final class Table
    {
        string Schema;
        string Name;
        string FullName;
        Column[] Columns;
        
        this(string schema, string name, Column[] columns) pure nothrow
        {
            Schema = schema;
            Name = name;
            FullName = schema ~ (schema.length == 0 ? "" : ".") ~ name;
            Columns = columns;
        }
    }
    
    private immutable struct Column
    {
        string Name;
        string Type;
    }
    
    public enum States { NotStarted, DataCollectionInProgress, Complete }
    
    private database.DatabaseManager _database;
    public static string CurrentSchema;
    
    private CommandWords baseCommandWords;
    public LinearLookup tableSchemasAndSimpleNames = new LinearLookup;
    private LinearLookup sequenceSchemasAndSimpleNames = new LinearLookup;
    private LinearLookup[string] schemasToTableNames;
    private LinearLookup[string] schemasToSequenceNames;
    private Table[string] tablesLookup;
    private Table lastTable;
    private States status = States.NotStarted;
    
    public NamedColor[string] IdentifierLookup;
    
    this()
    {
        baseCommandWords = new CommandWords;
        auto helpCommand = new CommandWords;
        baseCommandWords.AddWord("SELECT * FROM");
        baseCommandWords.AddWord("DELETE FROM WHERE");
        baseCommandWords.AddWord("INSERT INTO");
        baseCommandWords.AddWord("UPDATE");
        baseCommandWords.AddWord("MERGE INTO");
        baseCommandWords.AddWord("HELP", helpCommand);
        
        static foreach (target; getSymbolsByUDA!(Commands, CommandName))
            static foreach (commandName; getUDAs!(target, CommandName))
            {{
                static if (commandName.LongName != "HELP")
                {
                    auto subWords = new CommandWords;
                    
                    static foreach (subCommands; getUDAs!(target, SubCommands))
                        static foreach (subCommand; subCommands.Commands)
                            static if (subCommand.length > 0)
                                subWords.AddWord(subCommand);
                    
                    baseCommandWords.AddWord(commandName.LongName, subWords);
                    helpCommand.AddWord(commandName.LongName);
                    
                    static foreach (length; commandName.ShortName.length .. commandName.LongName.length)
                        baseCommandWords.AddAlias(commandName.LongName[0 .. length].strip, commandName.LongName);
                }
            }}
        
        auto setCommand = baseCommandWords.Words["SET"];
        
        static foreach (target; getSymbolsByUDA!(Settings, Settings.SettableByTheSetCommand))
            static foreach (commandName; getUDAs!(target, CommandName))
            {{
                auto subWords = new CommandWords;
                
                static foreach (subCommands; getUDAs!(target, SubCommands))
                    static foreach (subCommand; subCommands.Commands)
                        static if (subCommand.length > 0)
                            subWords.AddWord(subCommand);
                
                setCommand.AddWord(commandName.LongName, subWords);
            }}
        
        auto showCommand = baseCommandWords.Words["SHOW"];
        
        static foreach (target; getSymbolsByUDA!(Settings, Settings.DisplayedByTheShowCommand))
            static foreach (commandName; getUDAs!(target, CommandName))
            {{
                auto subWords = new CommandWords;
                
                static foreach (subCommands; getUDAs!(target, SubCommands))
                    static foreach (subCommand; subCommands.Commands)
                        static if (subCommand.length > 0)
                            subWords.AddWord(subCommand);
                
                showCommand.AddWord(commandName.LongName, subWords);
            }}
        
        // Make sure these are both pointing to the same collection of filenames 
        // (configured through AddDirectory()), and remap aliases.
        auto filenameCommandWords = new CommandWords;
        baseCommandWords.Words["START"] = filenameCommandWords;
        baseCommandWords.Words["EDIT"]  = filenameCommandWords;
        baseCommandWords.AddAlias("ED", "EDIT");
        baseCommandWords.AddAlias("EDI", "EDIT");
        baseCommandWords.AddAlias("@", "START");
        baseCommandWords.AddAlias("@@", "START");
    }
    
    public States Status() const @nogc nothrow { return status; }
    public void Status(States value) @nogc nothrow
    { 
        if (status == value)
            return;
        
        Program.Screen.Invalidate;
        status = value; 
    }
    
    public string[] AutoCompleteSuggestions;
    public int SuggestionMaxWidth;
    public int SelectedSuggestionIndex;
    public int VisibleSuggestionCount = 0;
    
    private bool suggestionPopupVisible = true;
    public bool SuggestionPopupVisible() const @nogc nothrow { return suggestionPopupVisible; }
    
    public bool ShowSuggestionPopup() @nogc nothrow
    { 
        if (suggestionPopupVisible || SelectedSuggestionIndex < 0)
            return false;
        
        suggestionPopupVisible = true;
        Program.Screen.Invalidate;
        return true;
    }
    
    public bool HideSuggestionPopup() @nogc nothrow
    {
        if (!suggestionPopupVisible || SelectedSuggestionIndex < 0)
            return false;
        
        suggestionPopupVisible = false;
        Program.Screen.Invalidate;
        return true;
    }
    
    public string CurrentSuggestion() @nogc nothrow
    {
        if (SelectedSuggestionIndex < 0 || SelectedSuggestionIndex >= AutoCompleteSuggestions.length)
            return null;
        
        return AutoCompleteSuggestions[SelectedSuggestionIndex];
    }
    
    public bool CompleteSuggestion()
    {
        if (!suggestionPopupVisible || SelectedSuggestionIndex < 0 || SelectedSuggestionIndex >= AutoCompleteSuggestions.length)
            return false;
        
        auto newText = CurrentSuggestion;
        const queryUtf32 = Program.Editor.Text.to!dstring;
        auto offset = Program.Editor.CursorOffset;
        
        auto wordStart = offset;
        while (wordStart > 0 && queryUtf32[wordStart - 1].IsOracleIdentifierCharacter!(ValidateCase.Either, ValidateDot.SingleWordOnly, ValidateQuote.AllowQuote))
            wordStart--;
        
        newText = newText.toUtf8Slice[offset - wordStart .. $];
        
        if (newText.length == 0)
            return false;
        
        if (newText.toUtf8Slice[$ - 1] != '"')
        {
            // Try to align the case with whatever the user has currently typed.
            
            while (true)
            {
                offset--;
                
                if (offset < 0 || offset >= queryUtf32.length)
                    break;
                
                // Non-alpha characters may be neither upper nor lower case.  Ignore these and look back further.
                if (queryUtf32[offset].isUpper)
                    break;
                
                if (queryUtf32[offset].isLower)
                {
                    newText = newText.toLower;
                    break;
                }
            }
        }
        
        Program.Editor.AddText(newText);
        return true;
    }
    
    public bool MoveSuggestionUp() @nogc nothrow
    {
        if (!suggestionPopupVisible || SelectedSuggestionIndex < 0)
            return false;
        
        if (SelectedSuggestionIndex > 0)
        {
            Program.Screen.Invalidate;
            SelectedSuggestionIndex--;
        }
        
        return true;
    }
    
    public bool MoveSuggestionDown() @nogc nothrow
    {
        if (!suggestionPopupVisible || SelectedSuggestionIndex < 0)
            return false;
        
        if (SelectedSuggestionIndex < AutoCompleteSuggestions.length - 1)
        {
            Program.Screen.Invalidate;
            SelectedSuggestionIndex++;
        }        
        
        return true;
    }
    
    public bool MoveSuggestionPageUp() @nogc nothrow
    {
        if (!suggestionPopupVisible || SelectedSuggestionIndex < 0)
            return false;
        
        if (SelectedSuggestionIndex > 0)
        {
            Program.Screen.Invalidate;
            SelectedSuggestionIndex = max(0, SelectedSuggestionIndex - VisibleSuggestionCount);
        }
        
        return true;
    }
    
    public bool MoveSuggestionPageDown() @nogc nothrow
    {
        if (!suggestionPopupVisible || SelectedSuggestionIndex < 0)
            return false;
        
        if (SelectedSuggestionIndex < AutoCompleteSuggestions.length - 1)
        {
            Program.Screen.Invalidate;
            SelectedSuggestionIndex = min(AutoCompleteSuggestions.intLength - 1, SelectedSuggestionIndex + VisibleSuggestionCount);
        }        
        
        return true;
    }
    
    void Connect(ConnectionDetails details)
    {
        if (_database is null)
            _database = new DatabaseManager(&ProcessThreadResult);
        else
        {
            _database.Cancel;
            _database.Disconnect;
        }
         
        tableSchemasAndSimpleNames.Clear;
        sequenceSchemasAndSimpleNames.Clear;
        IdentifierLookup = null;
        tablesLookup = null;
        schemasToTableNames = null;
        schemasToSequenceNames = null;
        lastTable = null;
        
        details.isSilent = true;
        _database.Connect!(No.isPrimaryThread)(details);
    }
    
    private void ProcessThreadResult(InstructionResult result)
    {
        result.match!(
            (StatusFlags     statusFlags) { }, 
            (OracleColumns oracleColumns) { }, 
            (OracleRecord   oracleRecord) => ReceiveRecord(oracleRecord), 
            (SqlSuccess sqlSuccess)
            {
                _database.Disconnect;
                Complete;
            }, 
            (SqlError sqlError)
            {
                Program.Buffer.AddText("Cannot prepare autocomplete list: " ~ sqlError.Error);
                _database.Disconnect;
            }, 
            (MessageResult messageResult)
            {
                final switch (messageResult.Type) with (MessageResultType)
                {
                    case Information:
                        Program.Buffer.AddText(messageResult.Message);
                        break;
                    

                    case Warning:
                        
                        if (Program.Settings.IsShowingSqlWarnings)
                            Program.Buffer.AddText(messageResult.Message, NamedColor.Warning);
                        
                        break;
                    
                    case Connected:
                        Status = States.DataCollectionInProgress;
                        QueryDatabaseObjects;
                        break;
                    
                    case NlsDateFormat:
                        break;
                    
                    case Disconnected:
                        break;
                    
                    case Cancelled:
                        break;
                    
                    case PasswordExpired:
                        break;
                    
                    case Failure:
                        Program.Buffer.AddText("Cannot prepare autocomplete list: " ~ messageResult.Message);
                        _database.Disconnect;
                        break;
                    
                    case ThreadFailure:
                        throw new NonRecoverableException(messageResult.Message);
                }
            }
        );
    }
    
    void Cancel()
    {
        if (_database is null)
            return;
        
        _database.Cancel;
    }
    
    void Kill()
    {
        if (_database is null)
            return;
        
        _database.Kill;    
    }
    
    void QueryDatabaseObjects()
    {
        auto dataDictionarySql = 
            "SELECT 'CURRENT_SCHEMA'                         AS object_type,                            \n" ~ 
            "       1                                        AS object_type_order,                      \n" ~ 
            "       SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') AS owner,                                  \n" ~ 
            "       NULL,                                                                               \n" ~ 
            "       NULL,                                                                               \n" ~ 
            "       NULL                                                                                \n" ~ 
            "  FROM dual                                                                                \n" ~ 
            "UNION ALL                                                                                  \n" ~ 
            "SELECT 'COLUMN'                AS object_type,                                             \n" ~ 
            "       2                       AS object_type_order,                                       \n" ~ 
            "       owner,                                                                              \n" ~ 
            "       table_name,                                                                         \n" ~ 
            "       column_name,                                                                        \n" ~ 
            "       DECODE(nullable, 'N', '* ', '  ') ||                                                \n" ~ 
            "           CASE                                                                            \n" ~ 
            "                WHEN data_type = 'NUMBER' THEN                                             \n" ~ 
            "                    data_type || '(' ||                                                    \n" ~ 
            "                    NVL2(data_precision, TO_CHAR(data_precision), TO_CHAR(data_length)) || \n" ~ 
            "                    NVL2(data_scale, ', ' || TO_CHAR(data_scale), '') || ')'               \n" ~ 
            "                WHEN data_type IN ('CHAR', 'VARCHAR', 'VARCHAR2') THEN                     \n" ~ 
            "                    data_type || '(' ||                                                    \n" ~ 
            "                    TO_CHAR(data_length) || ')'                                            \n" ~ 
            "                ELSE data_type                                                             \n" ~ 
            "           END AS type                                                                     \n" ~ 
            "  FROM all_tab_columns                                                                     \n" ~ 
            "UNION ALL                                                                                  \n" ~ 
            "SELECT 'SYNONYM'               AS object_type,                                             \n" ~ 
            "       3                       AS object_type_order,                                       \n" ~ 
            "       table_owner,                                                                        \n" ~ 
            "       table_name,                                                                         \n" ~ 
            "       NULLIF(owner, 'PUBLIC') AS synonym_owner,                                           \n" ~ 
            "       synonym_name --,                                                                    \n" ~ 
            "       -- db_link                                                                          \n" ~ 
            "  FROM all_synonyms                                                                        \n" ~ 
            "UNION ALL                                                                                  \n" ~ 
            "SELECT 'SEQUENCE'              AS object_type,                                             \n" ~ 
            "       4                       AS object_type_order,                                       \n" ~ 
            "       sequence_owner          AS sequence_owner,                                          \n" ~ 
            "       sequence_name,                                                                      \n" ~ 
            "       NULL,                                                                               \n" ~ 
            "       NULL                                                                                \n" ~ 
            "  FROM all_sequences                                                                       \n" ~ 
            "UNION ALL                                                                                  \n" ~ 
            "SELECT 'PROCEDURE'             AS object_type,                                             \n" ~ 
            "       5                       AS object_type_order,                                       \n" ~ 
            "       NULLIF(owner, 'PUBLIC') AS procedure_owner,                                         \n" ~ 
            "       object_name,                                                                        \n" ~ 
            "       procedure_name,                                                                     \n" ~ 
            "       " ~ (_database.isProcedureTypeInDataDictionary ? "object_type" : "''") ~ "          \n" ~ 
            "  FROM all_procedures                                                                      \n" ~ 
            "UNION ALL                                                                                  \n" ~ 
            "SELECT 'VIEW'                 AS object_type,                                              \n" ~ 
            "       6                      AS object_type_order,                                        \n" ~ 
            "       owner,                                                                              \n" ~ 
            "       view_name,                                                                          \n" ~ 
            "       NULL,                                                                               \n" ~ 
            "       NULL                                                                                \n" ~ 
            "  FROM all_views                                                                           \n" ~ 
            " ORDER BY 2, 3, 4, 5                                                                       \n";
        
        _database.Execute(dataDictionarySql, 0);
    }
    
    void ReceiveRecord(OracleRecord record)
    {
        string AddQuotesIfNecessary(string source)
        {
            if (source.length == 0)
                return source;
            
            if (source[0] == '\"' && source[$ - 1] == '\"')
                source = source[1 .. $ - 1];
            
            foreach (ch; source.byDchar)
                if (!ch.IsOracleIdentifierCharacter!(ValidateCase.UpperCaseOnly))
                    return "\"" ~ source ~ "\"";
            
            return source;
        }
        
        switch (record.getString(0))
        {
            case "CURRENT_SCHEMA":
                CurrentSchema = AddQuotesIfNecessary(record.getString(2));
                break;
                
            case "COLUMN":
                AddColumn(
                    AddQuotesIfNecessary(record.getString(2)), 
                    AddQuotesIfNecessary(record.getString(3)), 
                    Column(
                        AddQuotesIfNecessary(record.getString(4)), 
                        AddQuotesIfNecessary(record.getString(5))
                        )
                    );
                
                break;
                
            case "SYNONYM":
                AddSynonym(
                    AddQuotesIfNecessary(record.getString(2)), 
                    AddQuotesIfNecessary(record.getString(3)), 
                    AddQuotesIfNecessary(record.getString(4)), 
                    AddQuotesIfNecessary(record.getString(5)));
                
                break;
                
            case "SEQUENCE":
                AddSequence(
                    AddQuotesIfNecessary(record.getString(2)), 
                    AddQuotesIfNecessary(record.getString(3)));
                
                break;
                
            case "PROCEDURE":
                AddProcedure(
                    AddQuotesIfNecessary(record.getString(2)), 
                    AddQuotesIfNecessary(record.getString(3)), 
                    AddQuotesIfNecessary(record.getString(4)), 
                    AddQuotesIfNecessary(record.getString(5)));
                
                break;
                
            case "VIEW":
                AddView(
                    AddQuotesIfNecessary(record.getString(2)), 
                    AddQuotesIfNecessary(record.getString(3)));
                
                break;
                
            default: 
                throw new RecoverableException("Unexpected record type returned from Autocomplete QueryDatabaseObjects.");
        }
    }
    
    void AddColumn(string schema, string tableName, Column column)
    {
        IdentifierLookup[schema]      = NamedColor.Identifier;
        IdentifierLookup[tableName]   = NamedColor.Identifier;
        IdentifierLookup[column.Name] = NamedColor.Identifier;
        
        if (lastTable !is null &&
            schema    == lastTable.Schema &&
            tableName == lastTable.Name)
        {
            if (lastTable.Columns.length > 0)
            {
                auto lastcolumn = lastTable.Columns[$ - 1];
                
                if (column.Name == lastcolumn.Name)
                    return;
            }
            
            lastTable.Columns ~= column;
            return;
        }
        
        lastTable = new Table(schema, tableName, [column]);
        tablesLookup[schema ~ "." ~ tableName] = lastTable;
        
        auto schemaLookup = schemasToTableNames.require(schema, new LinearLookup);
        schemaLookup.Add(tableName);
        
        tableSchemasAndSimpleNames.Add(schema);
        
        if (schema == AutoCompleteManager.CurrentSchema)
            tableSchemasAndSimpleNames.Add(tableName);
        
        AddDottedMembersToCommand("DESCRIBE", schema, tableName);
    }
    
    void AddView(string schema, string name)
    {
        AddDottedMembersToCommand("SOURCE", schema, name);
    }
    
    void AddSynonym(string tableSchema, string tableName, string synonymSchema, string synonymName)
    {
        auto tableRef = (tableSchema ~ "." ~ tableName) in tablesLookup;
        if (tableRef is null)
            return;
        
        IdentifierLookup[synonymSchema] = NamedColor.Identifier;
        IdentifierLookup[synonymName] = NamedColor.Identifier;
        
        auto table = *tableRef;
        
        if (synonymSchema.length > 0)
        {
            tablesLookup[synonymSchema ~ "." ~ synonymName] = table;
            tableSchemasAndSimpleNames.Add(synonymSchema);
        }
        
        if (synonymSchema.length == 0 || synonymSchema == AutoCompleteManager.CurrentSchema)
        {
            tablesLookup[synonymName] = table;
            tableSchemasAndSimpleNames.Add(synonymName);
        }
    }
    
    void AddSequence(string schema, string name)
    {
        IdentifierLookup[name] = NamedColor.Identifier;
        
        if (schema.length == 0)
        {
            sequenceSchemasAndSimpleNames.Add(name);
        }
        else
        {
            IdentifierLookup[schema] = NamedColor.Identifier;
            sequenceSchemasAndSimpleNames.Add(schema);
            auto schemaLookup = schemasToSequenceNames.require(schema, new LinearLookup);
            schemaLookup.Add(name);
        }
        
        AddDottedMembersToCommand("DESCRIBE", schema, name);
    }
    
    void AddProcedure(string schema, string name, string subName, string type)
    {
        AddDottedMembersToCommand("EXECUTE", schema, name, subName);
        AddDottedMembersToCommand("SOURCE", schema, name);
        AddDottedMembersToCommand("DESCRIBE", schema, name, subName);
    }
    
    void AddDottedMembersToCommand(string commandName, string schema, string name, string subName = "")
    {
        auto executeCommand = baseCommandWords.RequireLookupFor(commandName);
        
        if (schema.length > 0)
        {
            IdentifierLookup[schema] = NamedColor.Identifier;
            
            auto schemaCommands = executeCommand.RequireLookupFor(schema, '.');
            
            if (name.length == 0)
            {
                if (subName.length > 0)
                    schemaCommands.Words[subName] = null;
            }
            else
            {
                auto packageCommands = schemaCommands.RequireLookupFor(name, '.');
                
                if (subName.length > 0)
                    packageCommands.Words[subName] = null;
            }
        }
        
        if (name.length > 0)
        {
            IdentifierLookup[name] = NamedColor.Package;
            
            auto packageCommands = executeCommand.RequireLookupFor(name, '.');
            
            if (subName.length > 0)
                packageCommands.Words[subName] = null;
        }
        
        if (subName.length > 0)
        {
            IdentifierLookup[subName] = NamedColor.Package;
            
            if (name.length == 0)
                executeCommand.Words[subName] = null;
        }
    }
    
    void AddDirectory(string path)
    {
        import std.path : baseName;
        import std.file : dirEntries, SpanMode, FileException;
    
        auto executeFileCommand = baseCommandWords.Words["START"];
        
        //baseCommandWords.Words.require("EDIT", executeFileCommand);
        
        try
        {
            foreach (file; dirEntries(path, SpanMode.shallow))
            {
                auto filename = file.name.baseName.toUpper;
                
                if (!filename.endsWith(".SQL"))
                    continue;
                
                filename = filename[0 .. $ - 4];
                
                if (filename.canFind(' '))
                    filename = "\"" ~ filename ~ "\"";
                
                executeFileCommand.AddWord(filename);
            }
        }
        catch (FileException) { }
    }
    
    void AddDefine(string variableName) =>
        baseCommandWords.Words["UNDEFINE"].AddWord(variableName);
    
    void RemoveDefine(string variableName) =>
        baseCommandWords.Words["UNDEFINE"].RemoveWord(variableName);
    
    void Complete()
    {
        tableSchemasAndSimpleNames.Complete;
        
        foreach (schemaLookup; schemasToTableNames)
            schemaLookup.Complete;
        
        foreach (schemaLookup; schemasToSequenceNames)
            schemaLookup.Complete;
        
        Status = States.Complete;
        
        lastCommand = null;
        Program.Screen.Invalidate;
    }
        
    private abstract class QueryComponentReference 
    {
        int ScopeStartOffset = 0;
        int ScopeEndOffset = int.max;
        
        void LimitEndOffsetTo(int scopeEndOffset) pure @nogc nothrow
        {
            ScopeEndOffset = min(ScopeEndOffset, scopeEndOffset);
        }
    }
    
    // Specifies a region where tables can be entered and so they should 
    // appear in the autocomplete list.
    private final class TableInput : QueryComponentReference
    {
        this (int scopeStartOffset, int scopeEndOffset) pure @nogc nothrow
        {
            ScopeStartOffset = scopeStartOffset;
            ScopeEndOffset = scopeEndOffset;
        }
    }
    
    // Specifies tables that have been mentioned in the query, and so their 
    // members should be in the autocomplete list.
    private final class TableReference : QueryComponentReference
    {
        string Schema;
        string TableName;
        string AliasName;
        string FullName;
        
        this (string schema, string tableName, string aliasName, int scopeStartOffset) pure
        {
            Schema = schema;
            TableName = tableName;
            AliasName = aliasName;
            ScopeStartOffset = scopeStartOffset;
            
            if (Schema.length > 0)
                FullName = Schema ~ "." ~ TableName;
            else
                FullName = TableName;
        }
    }
    
    // Specifies a column alias that the user may wish to reference elsewhere, 
    // and so should appear in the autocomplete list.  If TableName is populated, 
    // then this is an aliased inline view column.
    private final class UserDefinedColumn : QueryComponentReference
    {
        string TableName;
        string ColumnName;
        string FullName;
        
        this (string tableName, string columnName, int scopeStartOffset) pure
        {
            TableName = tableName;
            ColumnName = columnName;
            ScopeStartOffset = scopeStartOffset;
            FullName = TableName ~ "." ~ ColumnName;
        }
    }
    
    private string lastCommand;
    private int lastCursorOffset;
    QueryComponentReference[] lastComponents;
    
    public void UpdateSuggestions()
    {
        if (Program.Editor.HasAcceptPrompt)
            return;
        
        const command = Program.Editor.Text;
        const cursorOffset = Program.Editor.CursorOffset;
        
        if (command == lastCommand && cursorOffset == lastCursorOffset)
            return;
        
        auto newAutoCompleteSuggestions = FindSuggestionsWithoutCache(command, cursorOffset);
        
        lastCommand = command;
        lastCursorOffset = cursorOffset;
        
        if (newAutoCompleteSuggestions == AutoCompleteSuggestions)
            return;
        
        auto maxWidthInCharacters = 0;
        foreach (suggestion; newAutoCompleteSuggestions)
            maxWidthInCharacters = max(maxWidthInCharacters, suggestion.toUtf8Slice.intLength);
        
        
        AutoCompleteSuggestions = newAutoCompleteSuggestions;
        SuggestionMaxWidth = maxWidthInCharacters;
        
        foreach (index, suggestion; newAutoCompleteSuggestions)
            if (suggestion == CurrentSuggestion)
            {
                SelectedSuggestionIndex = cast(int)index;
                return;
            }
        
        if (newAutoCompleteSuggestions.length > 0)
        {
            SelectedSuggestionIndex = 0;
            suggestionPopupVisible = true;
        }
        else
            SelectedSuggestionIndex = -1;
    }
    
    public string[] FindSuggestionsWithoutCache(string command, int cursorOffset)
    {
        if (cursorOffset == 0)
            return null;
        
        const commandUtf32 = command.to!dstring;
        
        cursorOffset = min(cursorOffset, commandUtf32.intLength);
        
        if (cursorOffset < commandUtf32.length && 
            commandUtf32[cursorOffset].IsOracleIdentifierCharacter!(ValidateCase.Either, ValidateDot.AllowDot, ValidateQuote.AllowQuote))
            return null;
        
        auto wordStart = cursorOffset;
        while (wordStart > 0 && commandUtf32[wordStart - 1].IsOracleIdentifierCharacter!(ValidateCase.Either, ValidateDot.AllowDot, ValidateQuote.AllowQuote))
            wordStart--;
        
        auto currentWord = commandUtf32[wordStart .. cursorOffset];
        
        if (currentWord.length == 0)
        {
            auto isLineEmpty = true;
            ulong lineStart = cursorOffset;
            while (lineStart > 0 && 
                   commandUtf32[lineStart - 1] != '\r' && 
                   commandUtf32[lineStart - 1] != '\n')
            {
                if (commandUtf32[lineStart - 1] != ' ' &&
                    commandUtf32[lineStart - 1] != '\t')
                {
                    isLineEmpty = false;
                    break;
                }
                
                lineStart--;
            }
            
            if (isLineEmpty)
                return null;
        }
        
        if (currentWord.length > 0 && currentWord[0] != '\"')
            currentWord = currentWord.toUpper;
        
        if (!Interpreter.IsMultiLineCommand(command))
            return ParseCommand(command, cursorOffset, currentWord.to!string);
        
        if (Status != States.Complete)
            return null;
        
        const names = OracleNames.ParseName!(OracleNames.ParseQuotes.Keep)(currentWord.to!string);
        
        // These names might not be Schema.TableName.ColumnName because we could have either 
        // Schema.TableName or TableName.ColumnName which may go into the wrong properties 
        // because the parser doesn't (and can't) know any better.  Rename them here so the 
        // following code is less confusing.
        const firstName  = names.Schema.length > 0 ? names.Schema     : names.ObjectName;
        const secondName = names.Schema.length > 0 ? names.ObjectName : names.SubName;
        const thirdName  = names.Schema.length > 0 ? names.SubName    : null;
        
        Table[] tables;
        string[] autoCompleteCandidates;
        
        lastComponents = command == lastCommand ? lastComponents : ParseQuery(command, 0);
        
        auto canAcceptTables = false;
        const isStartOfIdentifier = currentWord.length == 0 || currentWord[$ - 1] == '.';
        
        foreach (reference; lastComponents)
        {
            if (cursorOffset < reference.ScopeStartOffset || 
                cursorOffset > reference.ScopeEndOffset)
                continue;
            
            if (cast(TableInput)reference !is null)
            {
                canAcceptTables = true;
                continue;
            }
            
            auto table = cast(TableReference)reference;
            if (table !is null)
            {
                auto tableRef = table.FullName in tablesLookup;
                
                if (tableRef is null)
                    tableRef = CurrentSchema ~ "." ~ table.TableName in tablesLookup;
                
                if (tableRef !is null)
                    tables ~= *tableRef;
                
                continue;
            }
            
            auto userColumn = cast(UserDefinedColumn)reference;
            if (userColumn !is null)
            {
                if (firstName.length == 0)
                {
                    autoCompleteCandidates ~= userColumn.TableName;
                    autoCompleteCandidates ~= userColumn.ColumnName;
                    
                    continue;
                }
                
                if (userColumn.TableName == firstName && ((secondName.length == 0 && isStartOfIdentifier) || userColumn.ColumnName.isExtensionOf(secondName)))
                    autoCompleteCandidates ~= userColumn.ColumnName;
                
                if ((userColumn.TableName.isExtensionOf(firstName) && secondName.length == 0 && !isStartOfIdentifier))
                    autoCompleteCandidates ~= userColumn.TableName;
            }
        }
        
        if (thirdName.length == 0)
        {
            if (canAcceptTables)
            {
                if (secondName.length == 0)
                {
                    autoCompleteCandidates ~= tableSchemasAndSimpleNames.LookupPartialText(firstName).array;
                    
                    if (isStartOfIdentifier)
                    {
                        if (firstName.length == 0)
                            autoCompleteCandidates ~= tableSchemasAndSimpleNames.Items;
                        else
                        {
                            auto tablesLookupRef = firstName in schemasToTableNames;
                            if (tablesLookupRef !is null)
                                autoCompleteCandidates ~= (*tablesLookupRef).Items;
                        }
                    }
                }
                else
                {
                    auto tablesLookupRef = firstName in schemasToTableNames;
                    if (tablesLookupRef !is null)
                        autoCompleteCandidates ~= (*tablesLookupRef).LookupPartialText(secondName).array;
                }
            }
            
            if (secondName.length == 0)
            {
                autoCompleteCandidates ~= sequenceSchemasAndSimpleNames.LookupPartialText(firstName).array;
                
                if (isStartOfIdentifier)
                {
                    if (firstName.length == 0)
                        autoCompleteCandidates ~= sequenceSchemasAndSimpleNames.Items;
                    else
                    {
                        auto sequencesLookupRef = firstName in schemasToSequenceNames;
                        if (sequencesLookupRef !is null)
                            autoCompleteCandidates ~= (*sequencesLookupRef).Items;
                    }
                    
                    foreach (reference; lastComponents)
                    {
                        auto table = cast(TableReference)reference;
                        if (table !is null && table.AliasName == firstName)
                        {
                            auto tableRef = table.FullName in tablesLookup;
                            
                            if (tableRef is null)
                                tableRef = CurrentSchema ~ "." ~ table.TableName in tablesLookup;
                            
                            if (tableRef !is null)
                                foreach (column; (*tableRef).Columns)
                                    autoCompleteCandidates ~= column.Name;                        
                            
                            continue;
                        }
                    }
                }
            }
            else
            {
                foreach (reference; lastComponents)
                {
                    auto table = cast(TableReference)reference;
                    if (table !is null && table.AliasName == firstName)
                    {
                        auto tableRef = table.FullName in tablesLookup;
                        
                        if (tableRef is null)
                            tableRef = CurrentSchema ~ "." ~ table.TableName in tablesLookup;
                        
                        if (tableRef !is null)
                            foreach (column; (*tableRef).Columns)
                                if (column.Name.isExtensionOf(secondName))
                                    autoCompleteCandidates ~= column.Name;                        
                        
                        continue;
                    }
                }
                
                auto sequencesLookupRef = firstName in schemasToSequenceNames;
                if (sequencesLookupRef !is null)
                    autoCompleteCandidates ~= (*sequencesLookupRef).LookupPartialText(secondName).array;
            }
        }
        
        foreach (table; tables)
        {
            if (firstName.length > 0 && secondName.length > 0 && thirdName.length > 0)
            {
                // Here we have all three names.
                if (table.Schema == firstName && 
                    table.Name   == secondName)
                {
                    foreach (column; table.Columns)
                        if (column.Name.isExtensionOf(thirdName))
                            autoCompleteCandidates ~= column.Name;
                }
            }
            else if (firstName.length > 0 && secondName.length > 0)
            {
                // Here we only have two names and they might be either schema/table, or table/column.
                if (isStartOfIdentifier)
                {
                    if (table.Schema == firstName && 
                        table.Name   == secondName)
                    {
                        foreach (column; table.Columns)
                            autoCompleteCandidates ~= column.Name;
                    }
                    
                    continue;                        
                }
                
                if (table.Schema == firstName && table.Name.isExtensionOf(secondName))
                    autoCompleteCandidates ~= table.Name;
                
                if (table.Name == firstName)
                    foreach (column; table.Columns)
                        if (column.Name.isExtensionOf(secondName))
                            autoCompleteCandidates ~= column.Name;                    
            }
            else
            {
                // Here we only have one name and it might be either a schema, table or column.
                // Don't bother with schemas because they shuold have been taken care of above.
                if (isStartOfIdentifier)
                {
                    if (table.Schema == firstName)
                        autoCompleteCandidates ~= table.Name;
                    
                    if (table.Name == firstName || firstName.length == 0)
                        foreach (column; table.Columns)
                            autoCompleteCandidates ~= column.Name;
                    
                    continue;
                }
                
                if (table.Name.isExtensionOf(firstName))
                    autoCompleteCandidates ~= table.Name;
                
                foreach (column; table.Columns)
                    if (column.Name.isExtensionOf(firstName))
                        autoCompleteCandidates ~= column.Name;
            }
        }
        
        return autoCompleteCandidates.sort.uniq.array;
    }
    
    private string[] ParseCommand(string commandText, const int startOffset, string currentWord) pure
    {
        commandText = commandText.toUtf8Slice[0 .. startOffset].strip;
        
        const dotPosition = lastIndexOf(currentWord, '.');
        if (dotPosition >= 0)
            currentWord = currentWord[dotPosition + 1 .. $];
        
        string[] FilterCurrentWord(const CommandWords command)
        {
            if (currentWord.length == 0)
                return command.Words.keys.sort.array;
            
            currentWord = currentWord.toUpper;
            string[] results;
            foreach (word; command.Words.keys)
                if (word.startsWith(currentWord))
                    results ~= word;
            
            return results.sort.array;
        }
        
        auto subCommandWords = baseCommandWords;
        while (true)
        {
            auto word = Interpreter.ConsumeToken!(Interpreter.SplitBy.Complex, ValidateDot.SingleWordOnly)(commandText).toUpper;
            
            if (word.length == 0)
                break;
            
            if (subCommandWords.Separator != ' ' && 
                word.length == 1 && 
                word[0] == subCommandWords.Separator)
            {
                word = Interpreter.ConsumeToken!(Interpreter.SplitBy.Complex, ValidateDot.SingleWordOnly)(commandText).toUpper;
                
                if (word.length == 0)
                    break;
            }
            
            auto nextCommandWordsRef = word in subCommandWords.Words;
            
            // Is this whole word expected?
            if (nextCommandWordsRef is null)
            {
                // Are we still typing this word?
                if (currentWord == word && commandText.length == 0)
                    break;
                
               nextCommandWordsRef = word in subCommandWords.Aliases;
               if (nextCommandWordsRef is null)
                   return null;
            }
            
            // Does this command have anything following it?
            if (*nextCommandWordsRef is null) 
                return null;
            
            subCommandWords = *nextCommandWordsRef;
        }
        
        return FilterCurrentWord(subCommandWords);
    }
    
    private QueryComponentReference[] ParseQuery(ref string query, int startOffset = 0) pure
    {
        QueryComponentReference[] results;
        
        enum SectionTypes { None, Select, From, With, Where, Boundary }
        
        SectionTypes keywordCategory(string token)
        {
            if (token == "WITH")
                return SectionTypes.With;
            
            if (token == "SELECT")
                return SectionTypes.Select;
                
            if (token == "FROM" || token == "JOIN" || token == "UPDATE" || token == "DELETE" || token == "MERGE" || token == "INSERT" || token == "INTO")
                return SectionTypes.From;
            
            if (token == "WHERE" || token == "ON" || token == "HAVING" || token == "BY" || token == "SET"  || token == "VALUES")
                return SectionTypes.Where;
            
            if (token == "UNION" || token == "INTERSECT" || token == "MINUS")
                return SectionTypes.Boundary;
            
            return SectionTypes.None;
        }
        
        
        auto inlineWithViewName = "";
        auto lastSectionType = SectionTypes.None;
        auto lastSectionStartOffset = 0;
        
        auto originalQueryLength = startOffset + query.toUtf8Slice.intLength;
        auto tokenStartOffset = startOffset;
        auto tokenEndOffset = startOffset;
        
        string GetNextToken()
        {
            while (query.length > 0)
            {
                tokenStartOffset = originalQueryLength - query.toUtf8Slice.intLength;
                auto token = Interpreter.ConsumeToken!(Interpreter.SplitBy.Complex)(query);
                
                tokenEndOffset = tokenStartOffset + token.toUtf8Slice.intLength;
                return token.toUpper;
            }
            
            return "";
        }
        
        auto token = GetNextToken;
        int loopCount = 0;
        while (!(query.length == 0 && token == ""))
        {
            loopCount++;
            if (loopCount > 65535)
                throw new NonRecoverableException("Parsing logic error.");
            
            auto sectionType = keywordCategory(token);
            
            if (keywordCategory(token) == SectionTypes.Boundary)
            {
                foreach (item; results)
                    item.LimitEndOffsetTo(tokenStartOffset);
                
                token = GetNextToken;
                if (token == "ALL")
                    token = GetNextToken;
                
                continue;
            }
            
            if (sectionType != SectionTypes.None)
            {
                if (lastSectionType == SectionTypes.From)
                    results ~= new TableInput(lastSectionStartOffset, tokenStartOffset);
                
                lastSectionType = sectionType;
                lastSectionStartOffset = tokenEndOffset;
                token = GetNextToken;
                continue;
            }
            
            if (token == ",")
            {
                token = GetNextToken;
                continue;
            }
            
            if (token == ")")
            {
                if (lastSectionType == SectionTypes.From)
                    results ~= new TableInput(lastSectionStartOffset, tokenStartOffset);
                
                return results;
            }
            
            if (token == "(")
            {
                auto children = ParseQuery(query, tokenEndOffset);
                auto scopeEndOffset = originalQueryLength - query.toUtf8Slice.intLength;
                token = GetNextToken;
                
                final switch (lastSectionType) with (SectionTypes)
                {
                    case None, Boundary:
                        // I'm not sure what would be happening here, so just pass through anything that was discovered inside.
                        break;
                    
                    case Where: 
                        // No scope expansion for subqueries in the WHERE clause.
                        break;
                    
                    case With:
                        foreach (child; children)
                        {
                            auto column = cast(UserDefinedColumn)child;
                            if (column !is null)
                            {
                                column.ScopeStartOffset = startOffset;
                                column.TableName = inlineWithViewName;
                            }
                            
                            auto table = cast(TableReference)child;
                            if (table !is null)
                                table.LimitEndOffsetTo(scopeEndOffset);
                        }
                        
                        inlineWithViewName = "";
                        break;
                    
                    case Select:
                        foreach(child; children)
                            child.LimitEndOffsetTo(scopeEndOffset);
                        
                        break;
                    
                    case From:
                        
                        if (keywordCategory(token) == SectionTypes.None && token != ",")
                            foreach (child; children)
                            {
                                auto column = cast(UserDefinedColumn)child;
                                if (column !is null)
                                {
                                    column.ScopeStartOffset = startOffset;
                                    column.TableName = token;
                                }
                            }
                        
                        foreach(child; children)
                        {
                            auto table = cast(TableReference)child;
                            if (table !is null)
                                table.LimitEndOffsetTo(scopeEndOffset);
                        }
                        break;
                }
                
                results ~= children;
                continue;
            }
            
            final switch (lastSectionType) with (SectionTypes)
            {
                case None, Boundary, Where:
                    token = GetNextToken;
                    continue;
                    
                case With:
                
                    if (token == "AS")
                    {
                        token = GetNextToken;
                        if (keywordCategory(token) != SectionTypes.None)
                            continue;
                    }
                    
                    inlineWithViewName = token;
                    token = GetNextToken;
                    continue;
                    
                case From:
                    
                    string schema = "";
                    string tableName = "";
                    foreach (subName; token.splitter('.'))
                    {
                        if (tableName.length > 0)
                        {
                            if (schema.length > 0) // Multiple dots?
                                break;
                        
                            schema = tableName;
                            tableName = subName;
                        }
                        else
                            tableName = subName;
                    }
                    
                    token = GetNextToken;
                    if (token == "" || token == "," || keywordCategory(token) != SectionTypes.None || !IsOracleIdentifier(token))
                        results ~= new TableReference(schema, tableName, "", startOffset);
                    else
                    {
                        results ~= new TableReference(schema, tableName, token, startOffset);
                        token = GetNextToken;
                    }
                    
                    continue;
                    
                case Select:
                    
                    auto field = token;
                    token = GetNextToken;
                    
                    if (IsOracleIdentifier(field) &&
                        (token == "," || 
                         keywordCategory(token) != SectionTypes.None))
                    {
                        results ~= new UserDefinedColumn("", field, startOffset);
                    }
                    
                    continue;
            }
        }
        
        if (lastSectionType == SectionTypes.From)
            results ~= new TableInput(lastSectionStartOffset, int.max);
        
        return results;
    }
    
    debug
    {
        void Attempt(string source)
        {
            void ParseAndPrint(string command)
            {
                Program.Buffer.AddText(command);
                
                foreach (reference; ParseQuery(command))
                {
                    auto tableInput = cast(TableInput)reference;
                    auto table      = cast(TableReference)reference;
                    auto column     = cast(UserDefinedColumn)reference;
                    
                    if (tableInput !is null)
                        Program.Buffer.AddText(
                            "    Table Input ".padRight(' ', 30).to!string ~ " " ~ 
                            tableInput.ScopeStartOffset.to!string.padRight(' ', 10).to!string ~ 
                            tableInput.ScopeEndOffset.to!string);
                    
                    if (table !is null)
                        Program.Buffer.AddText(
                            ("    Table: " ~ 
                            table.Schema ~ (table.Schema.length > 0 ? "." : "") ~  
                            table.TableName ~ (table.AliasName.length > 0 ? " AS " : "") ~  
                            table.AliasName).padRight(' ', 30).to!string ~ " " ~ 
                            table.ScopeStartOffset.to!string.padRight(' ', 10).to!string ~ 
                            table.ScopeEndOffset.to!string);
                    
                    if (column !is null)
                        Program.Buffer.AddText(
                            ("    Column: " ~ 
                            column.TableName ~ (column.TableName.length > 0 ? "." : "") ~  
                            column.ColumnName).padRight(' ', 30).to!string ~ 
                            column.ScopeStartOffset.to!string.padRight(' ', 10).to!string ~ 
                            column.ScopeEndOffset.to!string);
                }
                
                Program.Buffer.AddText("\n");
            }
            
            if (source.length > 0)
                ParseAndPrint(source);
            else
            {
                //             00000000001111111111222222222233333333334444444444555555555566666666667777777777
                //             01234567890123456789012345678901234567890123456789012345678901234567890123456789
                ParseAndPrint("SELECT 1 FROM dual ");
                ParseAndPrint("SELECT   1 FROM dual   d");
                ParseAndPrint("SELECT  1 FROM dual JOIN dual ON dummy = dummy");
                ParseAndPrint("SELECT  1 FROM dual a JOIN dual b ON dummy = dummy");
                ParseAndPrint("SELECT (SELECT 1 FROM dual) AS wibble FROM dual JOIN dual ON dummy = dummy");
                ParseAndPrint("SELECT 1 FROM (SELECT 1 AS wibble FROM dual)");
                ParseAndPrint("SELECT 1 FROM (SELECT 1 AS wibble FROM dual) d");
                ParseAndPrint("SELECT 1 FROM dual a WHERE EXISTS (SELECT 1 FROM dual b WHERE a.dummy = b.dummy)");
                ParseAndPrint("UPDATE some_table SET a = 34 WHERE wibble = 'WOBBLE';");
                ParseAndPrint("INSERT INTO some_table (a, b, c, d) VALUES (1, 2, 3, 4);");
                ParseAndPrint("DELETE FROM some_table WHERE wibble = 'WOBBLE';");
            }
        }
    }
}

public string getString(OracleRecord record, int index)
{
    return record[index].tryMatch!(
         (NullField           _) => "", 
         (string           text) => text, 
         //(const long      value) => value.to!string, 
         //(const double    value) => value.to!string, 
         //(OracleDate       date) => date.Text, 
    );
}

public class LinearLookup
{
    public string[] Items;
    private int[26 * 26] shortCuts;
    private bool isComplete = false;
    
    void Add(string item)
    {
        assert(!isComplete, "Lookup object requested Add after object was finalised.");
        Items ~= item;
    }
    
    void Clear()
    {
        Items = [];
        isComplete = false;
        shortCuts = 0;
    }
    
    void Complete()
    {
        Items = Items.sort.uniq.array;
        
        enum ZPlusOne = cast(char)(cast(ubyte)'Z' + 1);
        
        auto itemIndex = 0;
        auto shortCutIndex = 0;
        foreach(char1; 'A' .. ZPlusOne)
            foreach(char2; 'A' .. ZPlusOne)
            {
                shortCuts[shortCutIndex] = ()
                {
                    while (true)
                    {
                        if (itemIndex >= Items.length)
                            return Items.intLength;
                        
                        auto item = Items[itemIndex];
                        
                        if (item.length == 1)
                        {
                            if (item[0] > char1 || (item[0] == char1 && char2 == 'A'))
                                return itemIndex;
                        }
                        else if (item[0 .. 2] >= [char1, char2])
                            return itemIndex;
                        
                        itemIndex++;
                    }
                }();
                
                shortCutIndex++;
            }
        
        isComplete = true;
    }
    
    Results LookupPartialText(string partialName)
    {
        return Results(this, partialName);
    }
    
    private struct Results
    {
        private LinearLookup Owner;
        private string StartingText;
        private int Index = 0;
        
        private this(LinearLookup owner, string startingText)
        {
            Owner = owner;
            StartingText = startingText;
            Index = ()
            {
                if (StartingText.length == 0)
                    return Owner.Items.intLength;
                
                if (StartingText[0] < 'A')
                    return -1;
                
                auto shortCutIndex = min(StartingText[0] - 'A', 25) * 26;

                if (StartingText.length > 1 && StartingText[1] > 'A')
                    shortCutIndex += min(StartingText[1] - 'A', 25);
                
                return max(-1, Owner.shortCuts[shortCutIndex] - 2);
            }();
            
            popFront;
        }
        
        bool empty() const => Index >= Owner.Items.length;
        
        string front() const => Owner.Items[Index];
        
        void popFront() @nogc nothrow
        {
            while (true)
            {
                Index++;
                
                if (Index >= Owner.Items.length)
                    return;
                
                auto item = Owner.Items[Index];
                
                if (item.length <= StartingText.length)
                    continue;
                
                if (item[0 .. StartingText.length] < StartingText)
                    continue;
                
                if (item[0 .. StartingText.length] == StartingText)
                    return;
                
                Index = Owner.Items.intLength;
                return;
            }
        }
    }
}

// Returns true if fullText starts with startingText AND 
// is longer than startingText.
private bool isExtensionOf(string fullText, string startingText)
{
    return startingText.length > 0 && 
           fullText.length > startingText.length && 
           fullText.startsWith(startingText);
}

unittest
{
    auto l = new LinearLookup;
    
    l.Add("L");
    l.Add("LARGE");
    l.Add("LOAD1");
    l.Add("LOAD2");
    l.Complete;
    
    assert(l.LookupPartialText("L").array == [
        "LARGE", 
        "LOAD1", 
        "LOAD2"]);    
    assert(l.LookupPartialText("LA").array == [
        "LARGE"]);
    assert(l.LookupPartialText("LO").array == [
        "LOAD1", 
        "LOAD2"]);    
    assert(l.LookupPartialText("LOAD").array == [
        "LOAD1", 
        "LOAD2"]);    
    assert(l.LookupPartialText("LOAD1").array == []);
    
    l.Clear;
    l.Add("123");
    assert(l.LookupPartialText("LOAD1").array == []);
    assert(l.LookupPartialText("1").array == ["123"]);
    assert(l.LookupPartialText("12").array == ["123"]);
    
    l.Clear;
    l.Add("\"arw\"");
    assert(l.LookupPartialText("\"").array == ["\"arw\""]);
    assert(l.LookupPartialText("\"a").array == ["\"arw\""]);
    assert(l.LookupPartialText("\"arw\"").array == []);

    l.Clear;
    l.Add("A1");
    l.Add("A2");
    l.Add("AA");
    assert(l.LookupPartialText("A").array == ["A1", "A2", "AA"]);
}
