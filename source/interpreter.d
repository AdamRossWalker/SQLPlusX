module interpreter;

import std.algorithm : min, max;
import std.ascii : isAlpha, isAlphaNum, isDigit, isUpper, isWhite;
import std.array : split, join;
import std.algorithm : canFind, startsWith, endsWith, filter;
import std.conv: to, ConvException;
import std.range : dropBack, padLeft, repeat;
import std.string : toUpper, strip, stripLeft, splitLines, indexOf, lastIndexOf;
import std.traits : hasUDA, getUDAs, getSymbolsByUDA, EnumMembers, arity;
import std.typecons : Tuple;

import core.runtime;
import core.sys.windows.windows;
import std.windows.syserror;

import derelict.sdl2.sdl;

import program;
import range_extensions;

enum QueueAt { Start, End }
enum CommandSource { User, ScriptFile }

private struct CommandQueue
{
    alias Item = Tuple!(string, "Command", CommandSource, "Source", uint, "LineNumber");
    
    private const(Item)[] queue;
    public const(FormattedText)[] formattedLines;
    public const(int)[] formattedSectionsLengths;
    public int width = 0;
    
    public int length() const @nogc nothrow
    {
        return queue.intLength;
    }
    
    public int totalLines() const @nogc nothrow
    {
        return formattedLines.intLength;
    }
    
    public const(FormattedText)[] visibleLines(const int visibleLineCount)
    {
        return formattedLines[Program.Screen.queuedCommands.verticalScrollOffset .. min(Program.Screen.queuedCommands.verticalScrollOffset + visibleLineCount, $)];
    }
    
    private void updateWidth(const FormattedText[] formattedText = null)
    {
        foreach (line; formattedText)
            width = max(width, line.Text.intLength);
        
        if (queue.length == 0)
        {
            Program.Screen.queuedCommands.horizontalScrollOffset = 0;
            width = 0;
        }
    }
    
    public void clear() nothrow @nogc
    {
        queue = null;
        formattedLines = null;
        formattedSectionsLengths = null;
        Program.Screen.queuedCommands.verticalScrollOffset = 0;
        Program.Screen.queuedCommands.horizontalScrollOffset = 0;
    }
    
    public void enqueue(const Item item)
    {
        const formattedText = Program.Syntax.Highlight(item.Command);
        queue ~= item;
        formattedLines ~= formattedText;
        formattedSectionsLengths ~= formattedText.intLength;
        updateWidth(formattedText);
    }
    
    public Item dequeue()
    {
        auto item = queue[0];
        
        immutable formattedLength = formattedSectionsLengths[0];
        
        formattedLines = formattedLines[formattedLength .. $];
        formattedSectionsLengths = formattedSectionsLengths[1 .. $];
        Program.Screen.queuedCommands.verticalScrollOffset = max(0, Program.Screen.queuedCommands.verticalScrollOffset - formattedLength);
        queue = queue[1 .. $]; 
        updateWidth;
        
        return item;
    }
    
    public void insert(const Item item, const int position)
    {
        const formattedText = Program.Syntax.Highlight(item.Command);
        queue = queue[0 .. position] ~ item ~ queue[position .. $];
        
        auto formattedOffset = 0;
        foreach (formattedSectionsLength; formattedSectionsLengths[0 .. position])
            formattedOffset += formattedSectionsLength;
        
        formattedLines = formattedLines[0 .. formattedOffset] ~ formattedText ~ formattedLines[formattedOffset .. $];
        formattedSectionsLengths = formattedSectionsLengths[0 .. position] ~ formattedText.intLength ~ formattedSectionsLengths[position .. $];
        
        updateWidth(formattedText);
        
        if (Program.Screen.queuedCommands.verticalScrollOffset > 0 && 
            Program.Screen.queuedCommands.verticalScrollOffset >= formattedOffset)
            Program.Screen.queuedCommands.verticalScrollOffset += formattedText.intLength;
    }
    
    private void deleteAt(const int position)
    {
        auto formattedOffset = 0;
        foreach (formattedSectionsLength; formattedSectionsLengths[0 .. position])
            formattedOffset += formattedSectionsLength;
        
        immutable formattedLength = formattedSectionsLengths[position];
        
        formattedLines = formattedLines[0 .. formattedOffset] ~ formattedLines[formattedOffset + formattedLength .. $];
        formattedSectionsLengths = formattedSectionsLengths[0 .. position] ~ formattedSectionsLengths[position + 1 .. $];
        queue = queue[0 .. position] ~ queue[position + 1 .. $];
        updateWidth;
        
        if (Program.Screen.queuedCommands.verticalScrollOffset > 0 && 
            Program.Screen.queuedCommands.verticalScrollOffset >= formattedOffset)
            Program.Screen.queuedCommands.verticalScrollOffset -= formattedLength;
    }
    
    private void replaceAt(const Item item, const int position)
    {
        deleteAt(position);
        insert(item, position);
    }
    
    public bool extractFirstNonScriptLine(out string text)
    {
        // Try and feed in a later command into the ACCEPT PROMPT if they came
        // from the UI (and not a script).
        foreach (queueIndex, ref laterCommand; queue)
        {
            if (laterCommand.Source == CommandSource.ScriptFile)
                continue;
            
            if (formattedSectionsLengths[queueIndex] == 1)
            {
                text = laterCommand.Command;
                deleteAt(cast(int)queueIndex);
            }
            else
            {
                const lines = laterCommand.Command.splitLines;
                
                if (lines.length == 0)
                {
                    deleteAt(cast(int)queueIndex);
                    continue;
                }
                
                text = lines[0];
                
                if (lines.length == 1)
                    deleteAt(cast(int)queueIndex);
                else
                    replaceAt(Item(lines[1 .. $].join(lineEnding), laterCommand.Source, laterCommand.LineNumber), cast(int)queueIndex);
            }
            
            return true;
        }
        
        return false;
    }
}


public final class Interpreter
{
    // TODO: Investigate the following
    // expand? 
    // doc?
    
    public static bool IsMultiLineCommand(string command) pure @nogc nothrow
    {
        enum string[] multiLineStatementKeywords = 
        [
            "ALTER", 
            "ANALYZE", 
            "AUDIT", 
            "BEGIN", 
            "CALL", 
            "CHANGE", 
            "COMMENT", 
            "COMMIT", 
            "CREATE",
            "DECLARE", 
            "DELETE", 
            "DROP", 
            "EXPAND", 
            // "EXEC",   // I can't have both a mult-line EXEC and an exec without a 
            // "EXECU",  // semicolon.  And that might break scripts.
            // "EXECT", 
            // "EXECUTE", 
            "EXPLAIN", 
            "GRANT", 
            "IN", 
            "INPUT", 
            "INSERT", 
            "LOCK", 
            "MERGE", 
            "PURGE", 
            "RENAME", 
            "REVOKE", 
            "ROLLBACK", 
            "SELECT", 
            "TRUNCATE", 
            "UPDATE", 
            "VALIDATE", 
            "WITH"
        ];
        
        static foreach (keyword; multiLineStatementKeywords)
            if (StartsWithCommandWord!keyword(command.strip))
                return true;
        
        return false;
    }
    
    private static bool IsPassThroughCommand(string command) pure @nogc nothrow
    {
        static immutable passThroughKeywords = 
        [
            "ARCHIVE LOG", 
            "COMMIT", 
            "RECOVER", 
            "ROLLBACK", 
            "SAVEPOINT", 
            "SHUT", 
            "SHUTDOWN", 
            "STARTUP", 
        ];
        
        static foreach (keyword; passThroughKeywords)
            if (StartsWithCommandWord!keyword(command))
                return true;
        
        return false;
    }
    
    public static bool StartsWithCommandWord(string abbreviatedText, string fullText = abbreviatedText)(const string command) pure @nogc nothrow
    {
        string dummy;
        return StartsWithCommandWord!(abbreviatedText, fullText)(command, dummy);
    }
    
    public static bool StartsWithCommandWord(string abbreviatedText, string fullText = abbreviatedText)(const string command, ref string remainingCommand) pure @nogc nothrow
    {
        enum abbreviatedNames = abbreviatedText.split(' ');
        enum fullNames        = fullText.split(' ');
        
        static assert(abbreviatedNames.length == fullNames.length);
        
        auto commandIndex = 0;
        enum skip = "-";
        
        static foreach (nameIndex, fullName; fullNames)
        {{
            enum abbreviatedName = abbreviatedNames[nameIndex];
            enum abbreviatedNameLength = abbreviatedName.length;
          
            static assert(fullName.startsWith(abbreviatedName) || abbreviatedName == skip, 
                "Each abbreviated word must be the start of the full word.  Use a hyphen to signal this abbreviation is optional.");
            
            auto matchingCharacters = 0;
            foreach (characterIndex, character; fullName)
            {
                if (commandIndex >= command.length || 
                    command[commandIndex].toUpper != character)
                {
                    static if (abbreviatedName != skip)
                        if (matchingCharacters < abbreviatedNameLength)
                            return false;
                    
                    break;
                }
                
                commandIndex++;
                matchingCharacters++;
            }
            
            if (commandIndex < command.length)
            {
                if (command[commandIndex].isWhite)
                    commandIndex++;
                else
                    static if (nameIndex < fullNames.length - 1)
                        return false;
                    else if (command[commandIndex].IsOracleIdentifierCharacter!(ValidateCase.Either, ValidateDot.SingleWordOnly))
                        return false;
            }
        }}
        
        remainingCommand = command[commandIndex .. $].strip;
        return true;
    }
    
    enum SplitBy { WhiteSpace, Complex }
    
    public static string ConsumeToken(
        SplitBy       splitMethod = SplitBy.WhiteSpace, 
        ValidateDot   dotMode     = ValidateDot.AllowDot)(ref string remainingCommand) pure @nogc nothrow
    {
        auto index = -1;
        
        char GetNextCharacter()
        {
            if (index >= remainingCommand.intLength)
                return '\0';
            
            index++;
            
            if (index == remainingCommand.length)
                return '\0';
            else
                return remainingCommand[index];
        }
        
        string ExtractParameter(int startOffset, int endOffset)
        {
            auto parameter = remainingCommand[startOffset .. endOffset];
            remainingCommand = remainingCommand[endOffset .. $].stripLeft;
            return parameter;
        }
        
        while (true)
        {
            char character;
            
            do
                character = GetNextCharacter;
            while (character != '\0' && character.isWhite);
            
            if (character == '\0')
            {
                remainingCommand = "";
                return "";
            }
            
            if (character == '-' && 
                remainingCommand.length > index + 1 && 
                remainingCommand[index + 1] == '-')
            {
                index++;
                
                do
                    character = GetNextCharacter;
                while (character != '\0' && character != '\r' && character != '\n');
                
                continue;
            }
            
            if (character == '/' &&
                remainingCommand.length > index + 1 && 
                remainingCommand[index + 1] == '*')
            {
                index++;
                
                do
                    character = GetNextCharacter;
                while (character != '\0' &&
                           !(character == '*' &&
                             remainingCommand.length > index + 1 && 
                             remainingCommand[index + 1] == '/'));
                
                continue;
            }
            
            if (character == '\'')
            {
                auto startOffset = index;
                
                do
                    character = GetNextCharacter;
                while (character != '\0' && character != '\'');
                
                if (character != '\0')
                    index++;
                
                return ExtractParameter(startOffset, index);
            }
            
            if (character == '"')
            {
                auto startOffset = index;
                
                do
                    character = GetNextCharacter;
                while (character != '\0' && character != '"');  
                
                if (character != '\0')
                    index++;
                
                return ExtractParameter(startOffset, index);
            }
            
            static if (splitMethod == SplitBy.WhiteSpace)
            {
                auto startOffset = index;
                
                do
                    character = GetNextCharacter;
                while (character != '\0' && !character.isWhite);
                
                return ExtractParameter(startOffset, index);
            }
            else
            {
                if (character.IsOracleIdentifierCharacter!(ValidateCase.Either, dotMode))
                {                                            
                    auto startOffset = index;              
                    
                    do
                        character = GetNextCharacter;
                    while (character != '\0' && character.IsOracleIdentifierCharacter!(ValidateCase.Either, dotMode));
                    
                    return ExtractParameter(startOffset, index);
                }
                
                if (indexOf("()*+-/.", character) >= 0)
                    return ExtractParameter(index, index + 1);                
                
                auto startOffset = index;
                do
                    character = GetNextCharacter;
                while (!(character == '\0' || 
                         character == ' '  || 
                         character == '\'' || 
                         character == '\"' || 
                         character.IsOracleIdentifierCharacter!(ValidateCase.Either, dotMode) || 
                         indexOf("()*+-/", character) >= 0));
                
                return ExtractParameter(startOffset, index);
            }
        }
    }
    
    unittest
    {
        string remainingCommand;
        assert(StartsWithCommandWord!("ED", "EDIT")("ED", remainingCommand));
        assert(remainingCommand == "");
        
        assert(StartsWithCommandWord!("ED", "EDIT")("EDI", remainingCommand));
        assert(remainingCommand == "");
        
        assert(StartsWithCommandWord!("ED", "EDIT")("edit", remainingCommand));
        assert(remainingCommand == "");
        
        assert(StartsWithCommandWord!("ED", "EDIT")("EDIT ", remainingCommand));
        assert(remainingCommand == "");
        
        assert(StartsWithCommandWord!("ED", "EDIT")("EDIT Wibble", remainingCommand));
        assert(remainingCommand == "Wibble");
        
        
        assert(!StartsWithCommandWord!("ED", "EDIT")("EDITWibble", remainingCommand));
        
        assert(StartsWithCommandWord!("COMMIT -", "COMMIT WORK")("COMMIT", remainingCommand));
        assert(remainingCommand == "");
        
        assert(StartsWithCommandWord!("COMMIT -", "COMMIT WORK")("COMMIT work", remainingCommand));
        assert(remainingCommand == "");
        
        assert(!StartsWithCommandWord!("COMMIT -", "COMMIT WORK")("COMMI", remainingCommand));
        
        assert(StartsWithCommandWord!("SHO ERR", "SHOW ERRORS")("SHO ERR", remainingCommand));
        assert(remainingCommand == "");
        
        assert(StartsWithCommandWord!("SHO ERR", "SHOW ERRORS")("SHOW ERR", remainingCommand));
        assert(remainingCommand == "");
        
        assert(StartsWithCommandWord!("SHO ERR", "SHOW ERRORS")("SHO ERRORS", remainingCommand));
        assert(remainingCommand == "");
        
        assert(!StartsWithCommandWord!("SHO ERR", "SHOW ERRORS")("SH ERRORS", remainingCommand));
        
        assert(!StartsWithCommandWord!("SHO ERR", "SHOW ERRORS")("SHOW ER", remainingCommand));
        
        assert(!StartsWithCommandWord!("SHO ERR", "SHOW ERRORS")("SHOW", remainingCommand));
        
        
        void TestConsumeToken(SplitBy splitBy)(ref string input, string expectedParameter, string expectedRemainingCommand)
        {
            auto token = ConsumeToken!(splitBy)(input);
            
            assert(token == expectedParameter,        "Result \"" ~ token ~ "\", Expected \"" ~ expectedParameter ~ "\".");
            assert(input == expectedRemainingCommand, "Remaining Command \"" ~ input ~ "\", Expected \"" ~ expectedRemainingCommand ~ "\".");
        }
        
        remainingCommand = "TEST1 TEST2%^&*;   TEST3";
        TestConsumeToken!(SplitBy.Complex)(remainingCommand, "TEST1",     "TEST2%^&*;   TEST3");
        TestConsumeToken!(SplitBy.Complex)(remainingCommand, "TEST2",     "%^&*;   TEST3");
        TestConsumeToken!(SplitBy.Complex)(remainingCommand, "%^&",       "*;   TEST3");
        TestConsumeToken!(SplitBy.Complex)(remainingCommand, "*",         ";   TEST3");
        TestConsumeToken!(SplitBy.Complex)(remainingCommand, ";",         "TEST3");
        TestConsumeToken!(SplitBy.Complex)(remainingCommand, "TEST3",     "");
        
        remainingCommand = "TEST4 'TEST5 \" TEST6' \"TEST7 ' TEST8\" ";
        TestConsumeToken!(SplitBy.Complex)(remainingCommand, "TEST4",                 "'TEST5 \" TEST6' \"TEST7 ' TEST8\" ");
        TestConsumeToken!(SplitBy.Complex)(remainingCommand, "'TEST5 \" TEST6'",      "\"TEST7 ' TEST8\" ");
        TestConsumeToken!(SplitBy.Complex)(remainingCommand, "\"TEST7 ' TEST8\"",     "");
        
        
        remainingCommand = "TEST1 TEST2%^&*;   TEST3";
        TestConsumeToken!(SplitBy.WhiteSpace)(remainingCommand, "TEST1",      "TEST2%^&*;   TEST3");
        TestConsumeToken!(SplitBy.WhiteSpace)(remainingCommand, "TEST2%^&*;", "TEST3");
        TestConsumeToken!(SplitBy.WhiteSpace)(remainingCommand, "TEST3",      "");
        
        remainingCommand = "TEST4 'TEST5 \" TEST6' \"TEST7 ' TEST8\" ";
        TestConsumeToken!(SplitBy.WhiteSpace)(remainingCommand, "TEST4",                 "'TEST5 \" TEST6' \"TEST7 ' TEST8\" ");
        TestConsumeToken!(SplitBy.WhiteSpace)(remainingCommand, "'TEST5 \" TEST6'",      "\"TEST7 ' TEST8\" ");
        TestConsumeToken!(SplitBy.WhiteSpace)(remainingCommand, "\"TEST7 ' TEST8\"",     "");
    }
    
    private string StripTerminatorAndSpaces(string command) pure
    {
        if (command.endsWith("*/"))
            return command.strip;
        
        if (command.endsWith('/', ';'))
            command = command.dropBack(1).strip;
        
        return command.strip;
    }
    
    // TODO: Consider adding these default defines:
    // 
    // DEFINE _DATE           = "19-APR-20" (CHAR)
    // DEFINE _CONNECT_IDENTIFIER = "XE" (CHAR)
    // DEFINE _USER           = "TESTDB" (CHAR)
    // DEFINE _PRIVILEGE      = "" (CHAR)
    // DEFINE _SQLPLUS_RELEASE = "1102000200" (CHAR)
    // DEFINE _EDITOR         = "Notepad" (CHAR)
    // DEFINE _O_VERSION      = "Oracle Database 11g Express Edition Release 11.2.0.2.0 - 64bit Production" (CHAR)
    // DEFINE _O_RELEASE      = "1102000200" (CHAR)
    
    private static bool TryFindSubstitution(const string command, out string name, out int startIndex, out int endIndex)
    {
        if (!Program.Settings.SubstitutionEnabled)
            return false;
        
        auto substitutionCharacter = Program.Settings.SubstitutionCharacter;
        foreach (index, character; command)
        {
            if (character != substitutionCharacter)
                continue;
            
            startIndex = cast(int)index;
            endIndex = cast(int)index + 1;
            while (endIndex < command.length)
            {
                auto nextCharacter = command[endIndex];
                if (!nextCharacter.isAlphaNum && nextCharacter != '_')
                    break;
                
                endIndex++;
            }
            
            name = command[startIndex + 1 .. endIndex].toUpper;
            return true;
        }
        
        return false;
    }
    
    private string SubstituteVariables(string command)
    {
        while (true)
        {
            string name;
            int startIndex;
            int endIndex;
            
            if (!TryFindSubstitution(command, name, startIndex, endIndex))
                return command;
            
            // TODO: This silently returns "" now.  I need to think this through.
            // if (!Settings.SubstitutionVariableExists(name))
            //     throw new NonRecoverableException("Undefined variable: " ~ name);  // TODO: we should be checking for these up front but I can't find it.
            
            auto value = Settings.SubstitutionVariable(name);
            command = command[0 .. startIndex] ~ value ~ command[endIndex .. $];
            
            if (Program.Settings.IsVerifyOn)
                Program.Buffer.AddText("Old: \"" ~ name ~ "\"" ~ lineEnding ~ "New: \"" ~ command ~ "\"" ~ lineEnding ~ lineEnding);
        }
    }
    
    
    public void ProcessFile(string filename, string parameters)
    {
        auto variableNumber = 1;
        while (parameters.length > 0)
        {
            Settings.SetSubstitutionVariable(variableNumber.to!string, ConsumeToken(parameters));
            variableNumber++;
        }
        
        // Don't use readText because our file may be ANSI, not UTF-8.
        import std.file : read;
        Execute!(CommandSource.ScriptFile, QueueAt.Start)(cast(immutable(char)[])filename.read);
    }
    
    CommandQueue commandQueue;
    
    public auto QueuedCommandCount() const @nogc nothrow { return commandQueue.length; }
    
    public bool CommandsInProgress() const @nogc nothrow
    {
        if (Program.Database.IsCommandInProgress)
            return true;
        
        return commandQueue.length > 0;
    }
    
    public void ClearQueue() nothrow
    {
        Program.Screen.Invalidate;
        commandQueue.clear;
    }
    
    public void Cancel()
    {
        ClearQueue;
        Program.Database.Cancel;
    }
    
    private void EnQueueCommand(CommandSource commandSource, QueueAt queueLocation = QueueAt.End)(string rawCommand, int lineNumber, ref int scriptFileQueueOffset)
    {
        void internalEnqueue(string commandText)
        {
            // If the command being processed is a run-script-command, then the contents
            // of that script need to be added to the queue.  However, they need to be 
            // added at the location of the run-script-command; so the start of the queue.
            // 
            // However, each internal command must be added in order.  That is; they cannot 
            // always be added at the start because that would reverse the order of the 
            // commands in the file.  This means an offset must be tracked and incremented 
            // when in this scenario.
            // 
            // Lastly, and easier method would have been to eagerly parse the file at the 
            // point it's added to the queue.  I did not want to go this route because it 
            // prevents recursive scripts.  (Yes people do this)
            
            auto command = CommandQueue.Item(commandText, commandSource, lineNumber);
            static if (queueLocation == QueueAt.End)
                commandQueue.enqueue(command);
            else
            {
                commandQueue.insert(command, scriptFileQueueOffset);
                scriptFileQueueOffset++;
            }
        }
        
        auto command = rawCommand.strip;
        string remainingCommand;
        
        if (command == "/" || (StartsWithCommandWord!("R", "RUN")(command, remainingCommand) && remainingCommand.length == 0))
            foreach (previousCommand; Program.Editor.CommandHistoryDescending)
                if (IsMultiLineCommand(previousCommand) || 
                    IsPassThroughCommand(previousCommand))
                {
                    internalEnqueue(previousCommand);
                    return;
                }
        
        static if (commandSource != CommandSource.ScriptFile)
        {
            // Perform an early check for commands that can be executed 
            // while commands on the queue are in progress.  For example, 
            // cancel needs to interrupt the queue.
            
            command = StripTerminatorAndSpaces(command);
            
            if (command == "")
                return;
            
            void outputCommand()
            {
                if (Interpreter.IsMultiLineCommand(rawCommand))
                    Program.Buffer.AddTextWithPrompt(Program.Syntax.Highlight(rawCommand));
                else
                    Program.Buffer.AddTextWithPrompt(rawCommand);
                
                Program.Buffer.AddBlankLine;
            }
            
            if (StartsWithCommandWord!("ED", "EDIT")(command, remainingCommand))
            {
                outputCommand;
                
                auto filename = ConsumeToken(remainingCommand);
                if (filename == "")
                {
                    // Empty EDIT should have been handled by the Editor class.
                    Program.Buffer.AddText("EDIT command requires a filename" ~ lineEnding);
                    return;
                }
                
                auto fullPath = Commands.FindFile(filename);
                if (fullPath is null)
                {
                    Program.Buffer.AddText("File not found: \"" ~ filename ~ "\"" ~ lineEnding);
                    return;
                }
                
                import std.process;
                spawnProcess([Program.Settings.ExternalEditorPath, fullPath]);
                return;
            }
            
            if (StartsWithCommandWord!"CANCEL"(command))
            {
                outputCommand;
                Cancel;
                return;
            }
            
            if (StartsWithCommandWord!("ROLL -", "ROLLBACK WORK")(command))
                Cancel;
            
            if (StartsWithCommandWord!("COMMIT -", "COMMIT WORK")(command))
            {
                if (CommandsInProgress)
                {
                    outputCommand;
                    Program.Buffer.AddText("Queued commits are not permitted.  Please check results first." ~ lineEnding, NamedColor.Alert);
                    return;
                }
            }
        }
        
        internalEnqueue(rawCommand);
    }
    
    public enum ConnectionPrompt { None, InProgress, NewPasswordFirstEntry, NewPasswordSecondEntry }
    
    private ConnectionPrompt connectionPrompt = ConnectionPrompt.None;
    private ConnectionDetails connectionInProgressDetails;
    
    public void BeginConnection(ConnectionPrompt connectionPrompt = ConnectionPrompt.InProgress)(ConnectionDetails details)
    if (connectionPrompt == ConnectionPrompt.InProgress || 
        connectionPrompt == ConnectionPrompt.NewPasswordFirstEntry)
    {
        this.connectionPrompt = connectionPrompt;
        connectionInProgressDetails = details;
    }
    
    private AcceptPrompt acceptPrompt = null;
    
    public void SetAcceptPrompt(AcceptPrompt acceptPrompt)
    {
        this.acceptPrompt = acceptPrompt;
        Program.Editor.SetAcceptPrompt(acceptPrompt);
    }
    
    public void CheckCommandQueue()
    {
        MainQueueLoop: while (true)
        {
            if (Program.Database.IsCommandInProgress)
                return;
            
            if (acceptPrompt !is null)
            {
                if (!acceptPrompt.HasResult)
                    return;
                
                if (acceptPrompt.Result.length == 0 &&
                      (acceptPrompt.Content == AcceptPrompt.ContentType.PressAnyKey || 
                       acceptPrompt.Content == AcceptPrompt.ContentType.Username || 
                       acceptPrompt.Content == AcceptPrompt.ContentType.Password || 
                       acceptPrompt.Content == AcceptPrompt.ContentType.NewPasswordFirstEntry || 
                       acceptPrompt.Content == AcceptPrompt.ContentType.NewPasswordSecondEntry || 
                       acceptPrompt.Content == AcceptPrompt.ContentType.Host))
                {
                    // Then let the user back out gracefully.
                    connectionPrompt = ConnectionPrompt.None;
                    connectionInProgressDetails = ConnectionDetails();
                    acceptPrompt = null;
                    continue;
                }
                
                Program.Buffer.AddTextWithPrompt(acceptPrompt.Prompt, (acceptPrompt.IsHidden ? repeat('*', acceptPrompt.Result.length).to!string : acceptPrompt.Result));
                
                final switch (acceptPrompt.Content) with (AcceptPrompt.ContentType)
                {
                    case SubstitutionVariable:
                        Settings.SetSubstitutionVariable(acceptPrompt.Name, acceptPrompt.Result);
                        break;
                        
                    case Username:
                        connectionInProgressDetails.username = acceptPrompt.Result;
                        break;
                        
                    case Password:
                        connectionInProgressDetails.password = acceptPrompt.Result;
                        break;
                        
                    case NewPasswordFirstEntry:
                        connectionInProgressDetails.newPassword = acceptPrompt.Result;
                        connectionPrompt = ConnectionPrompt.NewPasswordSecondEntry;
                        break;
                        
                    case NewPasswordSecondEntry:
                        if (connectionInProgressDetails.newPassword != acceptPrompt.Result)
                        {
                            Program.Buffer.AddText("Passwords do not match.");
                            connectionPrompt = ConnectionPrompt.NewPasswordFirstEntry;
                        }
                        else
                            connectionPrompt = ConnectionPrompt.InProgress;
                        
                        break;
                        
                    case Host:
                        connectionInProgressDetails.host = acceptPrompt.Result;
                        break;
                    
                    case ClearScreen:
                        auto result = acceptPrompt.Result.strip;
                        
                        if (result.length == 0 || result[0] == 'Y' || result[0] == 'y')
                        {
                            Program.Screen.showLogo = false;
                            Program.Buffer.Clear;
                        }
                        
                        break;
                    
                    case Find, PressAnyKey:
                        return;
                }
                
                acceptPrompt = null;
            }
            
            
            if (connectionPrompt == ConnectionPrompt.NewPasswordFirstEntry)
            {
                SetAcceptPrompt(new AcceptPrompt("New Password", "New Password: ", AcceptPrompt.ContentType.NewPasswordFirstEntry, AcceptPrompt.InputType.Text, true));
                continue;
            }
            
            if (connectionPrompt == ConnectionPrompt.NewPasswordSecondEntry)
            {
                SetAcceptPrompt(new AcceptPrompt("Re-type Password", "Re-type Password: ", AcceptPrompt.ContentType.NewPasswordSecondEntry, AcceptPrompt.InputType.Text, true));
                continue;
            }
            
            if (connectionPrompt == ConnectionPrompt.InProgress)
            {
                if (connectionInProgressDetails.username.length == 0)
                {
                    SetAcceptPrompt(new AcceptPrompt("User Name", "User Name: ", AcceptPrompt.ContentType.Username));
                    continue;
                }
                
                if (connectionInProgressDetails.password.length == 0)
                {
                    SetAcceptPrompt(new AcceptPrompt("Password",  " Password: ", AcceptPrompt.ContentType.Password, AcceptPrompt.InputType.Text, true));
                    continue;
                }
                
                if (connectionInProgressDetails.host.length == 0)
                {
                    SetAcceptPrompt(new AcceptPrompt("Host Name", "Host Name: ", AcceptPrompt.ContentType.Host));
                    continue;
                }
            }
            
            if (connectionPrompt != ConnectionPrompt.None)
            {
                connectionPrompt = ConnectionPrompt.None;
                Program.Database.Connect(connectionInProgressDetails);
                connectionInProgressDetails = ConnectionDetails();
                continue;
            }
            
            if (commandQueue.length == 0)
                return;
            
            auto rawCommandData = commandQueue.dequeue;
            
            auto command = rawCommandData.Command;
            auto commandSource = rawCommandData.Source;
            auto lineNumber = rawCommandData.LineNumber;
            
            if (commandSource != CommandSource.ScriptFile || Program.Settings.IsEchoScriptCommands)
            {
                if (Interpreter.IsMultiLineCommand(command))
                    Program.Buffer.AddTextWithPrompt(Program.Syntax.Highlight(command));
                else
                    Program.Buffer.AddTextWithPrompt(command);
                
                Program.Buffer.AddBlankLine;
            }
            
            command = StripTerminatorAndSpaces(command);
            
            if (command.startsWith("/*"))
            {
                auto endComment = command[2 .. $].indexOf("*/");
                
                if (endComment < 0)
                    continue;
                
                command = command[endComment + 4 .. $];
                
                if (command.length == 0)
                    continue;
            }
            
            if (command.startsWith("--"))
                continue;
            
            
            string remainingCommand;
            
            if (StartsWithCommandWord!("ACC", "ACCEPT")(command, remainingCommand))
            {
                auto name = ConsumeToken(remainingCommand).toUpper;
            
                if (name.length == 0)
                {
                    Program.Buffer.AddText("ACCEPT command missing variable name." ~ lineEnding);
                    continue;
                }
                
                auto type = AcceptPrompt.InputType.Text;
                if (Interpreter.StartsWithCommandWord!("CHAR")(remainingCommand, remainingCommand))
                {
                    // type = AcceptPrompt.InputType.Text;
                }
                else if (Interpreter.StartsWithCommandWord!("NUM", "NUMBER")(remainingCommand, remainingCommand))
                {
                    type = AcceptPrompt.InputType.Number;
                }
                else if (Interpreter.StartsWithCommandWord!("DATE")(remainingCommand, remainingCommand))
                {
                    type = AcceptPrompt.InputType.Date;
                }
                
                auto format = "";
                if (Interpreter.StartsWithCommandWord!("FOR", "FORMAT")(remainingCommand, remainingCommand))
                {
                    format = ConsumeToken(remainingCommand);
                }
                
                auto defaultValue = "";
                if (Interpreter.StartsWithCommandWord!("DEF", "DEFAULT")(remainingCommand, remainingCommand))
                {
                    defaultValue = ConsumeToken(remainingCommand);
                }
                
                auto prompt = "";
                if (Interpreter.StartsWithCommandWord!("PROMPT")(remainingCommand, remainingCommand))
                {
                    prompt = ConsumeToken(remainingCommand).strip(['\'']);
                }
                else if (Interpreter.StartsWithCommandWord!("NOPR", "NOPROMPT")(remainingCommand, remainingCommand))
                {
                    // prompt = "";
                }
                
                auto isHidden = Interpreter.StartsWithCommandWord!("HIDE")(remainingCommand, remainingCommand);
                
                Program.AutoCompleteDatabase.AddDefine(name);
                
                // Try and feed in a later command into the ACCEPT PROMPT if they came
                // from the UI (and not a script).
                string firstNonScriptLine;
                if (commandQueue.extractFirstNonScriptLine(firstNonScriptLine))
                {
                    Settings.SetSubstitutionVariable(name, firstNonScriptLine);
                    Program.Buffer.AddText(prompt ~ firstNonScriptLine);
                }
                else
                    SetAcceptPrompt(new AcceptPrompt(name, prompt, AcceptPrompt.ContentType.SubstitutionVariable, type, isHidden, defaultValue, format));
                
                continue;
            }
            
            // We need empty commands up to this point as they may be used to
            // "Feed into" the ACCEPT statements.
            if (command.length == 0)
                continue;
            
            command = SubstituteVariables(command);
            
            if (IsMultiLineCommand(command) || IsPassThroughCommand(command))
            {
                Program.Database.Execute(command, lineNumber);
                continue;
            }
            
            if (command[0] == '@')
            {
                if (command.length > 1 && command[1] == '@')
                    remainingCommand = command[2 .. $];
                else
                    remainingCommand = command[1 .. $];
                    
                Commands.Start(remainingCommand);
                continue;
            }
            
            static foreach (target; getSymbolsByUDA!(Commands, CommandName))
                static foreach(commandName; getUDAs!(target, CommandName))
                    if (StartsWithCommandWord!(commandName.ShortName, commandName.LongName)(command, remainingCommand))
                    {
                        enum parameterCount = arity!target;
                        static if (parameterCount == 0) 
                        {
                            if (remainingCommand.length == 0)
                                target();
                            else static if (hasUDA!(target, CommandUsage))
                                CommandUsage.OutputFor!target;
                            else
                                Program.Buffer.AddText(commandName.LongName ~ " unexpected parameter." ~ lineEnding);
                        }
                        else static if (parameterCount == 1) 
                        {
                            target(remainingCommand);
                        }
                        else static if (parameterCount == 2) 
                        {
                            target(remainingCommand, lineNumber);
                        }
                        
                        continue MainQueueLoop;
                    }
            
            Program.Buffer.AddText("Unknown command.");
        }
    }
    
    struct ExecuteCommandResult
    {
        string ExecutedCommands;
        string TrailingIncompleteCommands;
        
        this(string fullCommand, int offset)
        {
            ExecutedCommands           = fullCommand[0 .. offset];
            TrailingIncompleteCommands = fullCommand[offset .. $];
        }
    }
    
    // Split into individual commands by the terminators.  The user
    // may have pasted in a block of statements or a script.  Unlike 
    // SQLPlusW, don't consider terminators inside comments.
    private ExecuteCommandResult SplitCommands(CommandSource commandSource = CommandSource.User)(
        const string fullCommandText, 
        void delegate(string, int, ref int) processResult, 
        ref int scriptFileQueueOffset)
    {
        static if (commandSource == CommandSource.ScriptFile)
        {
            auto lineNumber = 1;
            auto commandLineCount = 0;
        }
        else
            enum lineNumber = 1;
        
        auto currentIndex = 0;
        auto commandStart = 0;
        auto isNewLine = false;  // Is currentIndex immediately after a newline? 
        auto isInMultiLineCommand = false;
        auto isStartOfCommand = true;
        
        int newLineCharacterCount()
        {
            if (fullCommandText[currentIndex] == '\n')
                return 1;
            
            if (fullCommandText[currentIndex]     == '\r' && currentIndex + 1 < fullCommandText.length && 
                fullCommandText[currentIndex + 1] == '\n')
                return 2;
            
            return 0;
        }
        
        void advance(bool isInComment = false, int numberOfCharactersToAdvance = 1)()
        {
            if (currentIndex >= fullCommandText.length)
                return;
            
            static if (!isInComment)
                if (!fullCommandText[currentIndex].isWhite)
                    isStartOfCommand = false;
            
            static if (numberOfCharactersToAdvance != 1)
                scope(exit)
                    if (currentIndex > fullCommandText.length)
                        currentIndex = fullCommandText.intLength;
            
            auto newLineCharacters = newLineCharacterCount;
            if (newLineCharacters == 0)
            {
                isNewLine = false;
                currentIndex += numberOfCharactersToAdvance;
                return;
            }
            
            isNewLine = true;
            
            static if (commandSource == CommandSource.ScriptFile)
                commandLineCount++;
            
            static if (numberOfCharactersToAdvance == 1)
                currentIndex += newLineCharacters;
            else
                currentIndex += numberOfCharactersToAdvance;
        }
        
        void processResultAndAdvance()
        {
            advance;
            processResult(fullCommandText[commandStart .. currentIndex], lineNumber, scriptFileQueueOffset);
            
            while (currentIndex < fullCommandText.length && fullCommandText[currentIndex].isWhite)
                advance;
            
            commandStart = currentIndex;
            isInMultiLineCommand = false;
            isStartOfCommand = true;
            
            static if (commandSource == CommandSource.ScriptFile)
            {
                lineNumber += commandLineCount;
                commandLineCount = 0;
            }
        }
        
        bool isRestOfLineBlank()
        {
            for (auto tempIndex = currentIndex + 1; tempIndex < fullCommandText.length; tempIndex++)
            {
                if (fullCommandText[tempIndex] == '\r' || 
                    fullCommandText[tempIndex] == '\n')
                    return true;
                
                if (fullCommandText[tempIndex].isWhite)
                    continue;
                
                return false;
            }
            
            return true;
        }
        
        mainCommandTextLoop:
        while (currentIndex < fullCommandText.length)
        {
            auto character = fullCommandText[currentIndex];
            auto nextCharacter = currentIndex + 1 < fullCommandText.length ? fullCommandText[currentIndex + 1] : ' ';
            
            if (character == '\'')
            {
                do
                    advance;
                while (currentIndex < fullCommandText.length && 
                       fullCommandText[currentIndex] != '\'');
                advance;
                isStartOfCommand = false;
                continue;
            }
            
            if (character == '\"')
            {
                do
                    advance;
                while (currentIndex < fullCommandText.length && 
                       fullCommandText[currentIndex] != '\"');
                
                advance;
                continue;
            }
            
            if (character == '-' && nextCharacter == '-')
            {
                advance!(true, 2);
                while (currentIndex < fullCommandText.length && newLineCharacterCount == 0)
                    advance!true;
                
                continue;
            }
            
            if (character == '/' && nextCharacter == '*')
            {
                advance!(true, 2);
                while (currentIndex + 1 < fullCommandText.length && 
                        !(fullCommandText[currentIndex]     == '*' && 
                          fullCommandText[currentIndex + 1] == '/'))
                {
                    advance!true;
                }
                
                advance!(true, 2);
                continue;
            }
            
            string remainingCommand;
            if (StartsWithCommandWord!"BEGIN"                      (fullCommandText[currentIndex .. $], remainingCommand) || 
                StartsWithCommandWord!"DECLARE"                    (fullCommandText[currentIndex .. $], remainingCommand) || 
                StartsWithCommandWord!"CREATE OR REPLACE FUNCTION" (fullCommandText[currentIndex .. $], remainingCommand) || 
                StartsWithCommandWord!"CREATE OR REPLACE PROCEDURE"(fullCommandText[currentIndex .. $], remainingCommand) || 
                StartsWithCommandWord!"CREATE OR REPLACE PACKAGE"  (fullCommandText[currentIndex .. $], remainingCommand) || 
                StartsWithCommandWord!"CREATE OR REPLACE TRIGGER"  (fullCommandText[currentIndex .. $], remainingCommand) || 
                StartsWithCommandWord!"CREATE OR REPLACE TYPE"     (fullCommandText[currentIndex .. $], remainingCommand) || 
                StartsWithCommandWord!"CREATE FUNCTION"            (fullCommandText[currentIndex .. $], remainingCommand) || 
                StartsWithCommandWord!"CREATE PROCEDURE"           (fullCommandText[currentIndex .. $], remainingCommand) || 
                StartsWithCommandWord!"CREATE PACKAGE"             (fullCommandText[currentIndex .. $], remainingCommand) || 
                StartsWithCommandWord!"CREATE TRIGGER"             (fullCommandText[currentIndex .. $], remainingCommand) || 
                StartsWithCommandWord!"CREATE TYPE"                (fullCommandText[currentIndex .. $], remainingCommand))
            {
                currentIndex = fullCommandText.intLength - remainingCommand.intLength;
                while (currentIndex < fullCommandText.length)
                {
                    if (Settings.BlockTerminatorCharacterEnabled &&
                        isNewLine && 
                        currentIndex + Settings.BlockTerminatorCharacter.length < fullCommandText.length && 
                        fullCommandText[currentIndex .. currentIndex + Settings.BlockTerminatorCharacter.length] == Settings.BlockTerminatorCharacter && 
                        isRestOfLineBlank)
                    {
                        // This is a cancelled query, ignore the current statement and the rest of this line.
                        while (currentIndex < fullCommandText.length && newLineCharacterCount == 0)
                            advance;
                        
                        advance;
                        commandStart = currentIndex;
                        isStartOfCommand = true;
                        continue mainCommandTextLoop;
                    }
                    
                    if (isNewLine && fullCommandText[currentIndex] == '/' && isRestOfLineBlank)
                    {
                        processResultAndAdvance;
                        continue mainCommandTextLoop;
                    }
                    
                    advance;
                }
                
                return ExecuteCommandResult(fullCommandText, commandStart);
            }
            
            if (character == ';' || (isNewLine && character == '/' && isRestOfLineBlank))
            {
                processResultAndAdvance;
                continue;
            }
            
            if (!isInMultiLineCommand && newLineCharacterCount > 0)
            {
                processResultAndAdvance;
                continue;
            }
            
            if (!isInMultiLineCommand &&
                isStartOfCommand && 
                IsMultiLineCommand(fullCommandText[currentIndex .. $]))
            {
                isInMultiLineCommand = true;
                advance;
                continue;
            }
            
            advance;
        }
        
        if (commandStart < fullCommandText.length)
        {
            static if (commandSource == CommandSource.User)
                if (IsMultiLineCommand(fullCommandText[commandStart .. $]))
                    return ExecuteCommandResult(fullCommandText, commandStart);
            
            processResultAndAdvance;
        }
        
        return ExecuteCommandResult(fullCommandText, fullCommandText.intLength);
    }
    
    unittest
    {
        auto interpreter = new Interpreter;
    
        auto results = new string[0];
        ExecuteCommandResult result;
        auto lineNumbers = new uint[0];
        auto scriptFileQueueOffset = 0;
        
        void Clear()
        {
            results = new string[0];
            lineNumbers = new uint[0];
            scriptFileQueueOffset = 0;
        }
        
        void Enqueue(string command, int lineNumber, ref int scriptFileQueueOffset)
        {
            results ~= command;
            lineNumbers ~= lineNumber;
        }
        
        Clear;
        result = interpreter.SplitCommands("SELECT 1 FROM dual", &Enqueue, scriptFileQueueOffset);
        assert (result.ExecutedCommands.length == 0);
        assert (results.length == 0);
        
        Clear;
        result = interpreter.SplitCommands("SELECT 2 FROM dual;SELECT 3 FROM dual", &Enqueue, scriptFileQueueOffset);
        assert (result.ExecutedCommands.length == 19);
        assert (results.length == 1);
        assert (results[0] == "SELECT 2 FROM dual;");
        
        Clear;
        result = interpreter.SplitCommands("aasdfas;SELECT 4 FROM dual", &Enqueue, scriptFileQueueOffset);
        assert (result.ExecutedCommands.length == 8, result.to!string);
        assert (results.length == 1);
        assert (results[0] == "aasdfas;");
        
        Clear;
        result = interpreter.SplitCommands("SELECT \"5;\" FROM dual;SELECT 6 FROM dual", &Enqueue, scriptFileQueueOffset);
        assert (result.ExecutedCommands.length == 22);
        assert (results.length == 1);
        assert (results[0] == "SELECT \"5;\" FROM dual;");
        
        Clear;
        result = interpreter.SplitCommands("SELECT \"6;/\" FROM dual;SELECT 7 FROM dual", &Enqueue, scriptFileQueueOffset);
        assert (result.ExecutedCommands.length == 23);
        assert (results.length == 1);
        assert (results[0] == "SELECT \"6;/\" FROM dual;");
        
        Clear;
        result = interpreter.SplitCommands("SELECT '8;' FROM dual;SELECT 9 FROM dual", &Enqueue, scriptFileQueueOffset);
        assert (result.ExecutedCommands.length == 22);
        assert (results.length == 1);
        assert (results[0] == "SELECT '8;' FROM dual;");
        
        Clear;
        result = interpreter.SplitCommands("SELECT '10;' FROM dual;SELECT 11 FROM dual", &Enqueue, scriptFileQueueOffset);
        assert (result.ExecutedCommands.length == 23);
        assert (results.length == 1);
        assert (results[0] == "SELECT '10;' FROM dual;");
        
        Clear;
        result = interpreter.SplitCommands("SELECT '11;/' FROM dual;SELECT 12 FROM dual", &Enqueue, scriptFileQueueOffset);
        assert (result.ExecutedCommands.length == 24);
        assert (results.length == 1);
        assert (results[0] == "SELECT '11;/' FROM dual;");
        
        Clear;
        result = interpreter.SplitCommands("SELECT '13;/'\n FROM dual\n;SELECT 14 FROM dual", &Enqueue, scriptFileQueueOffset);
        assert (result.ExecutedCommands.length == 26);
        assert (results.length == 1);
        assert (results[0] == "SELECT '13;/'\n FROM dual\n;");
        
        Clear;
        result = interpreter.SplitCommands("SELECT --15\n FROM dual\n14;SELECT 16 FROM dual", &Enqueue, scriptFileQueueOffset);
        assert (result.ExecutedCommands.length == 26);
        assert (results.length == 1);
        assert (results[0] == "SELECT --15\n FROM dual\n14;");
        
        Clear;
        result = interpreter.SplitCommands("SELECT --17;\r\n FROM dual\n14;SELECT 18 FROM dual", &Enqueue, scriptFileQueueOffset);
        assert (result.ExecutedCommands.length == 28);
        assert (results.length == 1);
        assert (results[0] == "SELECT --17;\r\n FROM dual\n14;");
        
        Clear;
        result = interpreter.SplitCommands("SELECT --19;\r\n FROM dual\n14;SELECT 20 FROM dual", &Enqueue, scriptFileQueueOffset);
        assert (result.ExecutedCommands.length == 28);
        assert (results.length == 1);
        assert (results[0] == "SELECT --19;\r\n FROM dual\n14;");
        
        Clear;
        result = interpreter.SplitCommands("SELECT 21 FROM dual\n/", &Enqueue, scriptFileQueueOffset);
        assert (result.TrailingIncompleteCommands.length == 0);
        assert (results.length == 1);
        assert (results[0] == "SELECT 21 FROM dual\n/");
        
        Clear;
        result = interpreter.SplitCommands("a1\r\na2\r\na3\n", &Enqueue, scriptFileQueueOffset);
        assert (result.TrailingIncompleteCommands.length == 0);
        assert (results.length == 3);
        assert (results[0] == "a1\r\n", "\"" ~ results[0] ~ "\"");
        assert (results[1] == "a2\r\n", "\"" ~ results[1] ~ "\"");
        assert (results[2] == "a3\n",   "\"" ~ results[2] ~ "\"");
        
        Clear;
        result = interpreter.SplitCommands!(CommandSource.ScriptFile)(
            "SELECT 22 FROM dual;\r\n" ~            //  1
            "SELECT 23 FROM dual;\r\n" ~            //  2
            "SELECT 24           \r\n" ~            //  3
            "  FROM dual;        \r\n" ~            //  4
            "SELECT 25           \n" ~              //  5
            "  FROM dual;        \n" ~              //  6
                                "\r\n" ~            //  7
                                "\n" ~              //  8
                                "\n" ~              //  9
            "SELECT 26           \n" ~              // 10
            "  FROM dual;        \n" ~              // 11
            "                  \r\n" ~              // 12
            "SET wibble ON     \r\n",               // 13
             &Enqueue, scriptFileQueueOffset); 
        assert (result.TrailingIncompleteCommands.length == 0);
        assert (results.length ==  6);
        assert (lineNumbers[0] ==  1);
        assert (lineNumbers[1] ==  2);
        assert (lineNumbers[2] ==  3);
        assert (lineNumbers[3] ==  5);
        assert (lineNumbers[4] == 10);
        assert (lineNumbers[5] == 13);
    }
    
    public auto ClearAcceptPrompt()
    {
        auto promptCleared = Program.Editor.ClearAcceptPrompt;
        acceptPrompt = null;
        connectionPrompt = ConnectionPrompt.None;
        connectionInProgressDetails = ConnectionDetails();
        return promptCleared;
    }
    
    public void ControlCBreak()
    {
        ClearAcceptPrompt;
        Cancel;
    }
    
    public ExecuteCommandResult Execute(CommandSource commandSource, QueueAt queueLocation = QueueAt.End)(const string fullCommandText, int scriptFileQueueOffset = 0)
    {
        try
            return SplitCommands!commandSource(fullCommandText, &EnQueueCommand!(commandSource, queueLocation), scriptFileQueueOffset);
        catch (RecoverableException exception)
        {
            Program.Buffer.AddText(exception.msg);
            return ExecuteCommandResult(fullCommandText, fullCommandText.intLength);
        }
    }
}

enum ValidateCase { Either, UpperCaseOnly }
enum ValidateDot { AllowDot, SingleWordOnly }
enum ValidateQuote { AllowQuote, SimpleIdentifierOnly }

// These are the characters that make up Oracle identifiers.  Note, we are not checking here 
// that an identifier starts with a text character.  This is just for finding a contiguous block 
// of text.
bool IsOracleIdentifierCharacter(
    ValidateCase  caseMode  = ValidateCase.Either, 
    ValidateDot   dotMode   = ValidateDot.AllowDot, 
    ValidateQuote quoteMode = ValidateQuote.SimpleIdentifierOnly)
    (const char c) pure @nogc nothrow
{
    if (c == '_' || c == '$' || c == '#' || (dotMode == ValidateDot.AllowDot && c == '.') || (quoteMode == ValidateQuote.AllowQuote && c == '"'))
        return true;

    static if (caseMode == ValidateCase.Either)
        return c.isAlphaNum;
    else
        return c.isUpper || c.isDigit;
}

bool IsOracleIdentifierCharacter(
    ValidateCase  caseMode  = ValidateCase.Either, 
    ValidateDot   dotMode   = ValidateDot.AllowDot, 
    ValidateQuote quoteMode = ValidateQuote.SimpleIdentifierOnly)
    (const dchar c) pure @nogc nothrow
{
    return IsOracleIdentifierCharacter!(caseMode, dotMode, quoteMode)(cast(char)c);
}

bool IsOracleIdentifier(string token) pure @nogc nothrow
{
    return token.length > 0 && isAlpha(token[0]);
}
