module commands;

import std.array : appender, array, replicate, replace;
import std.algorithm : filter, max, splitter, startsWith, substitute;
import std.conv : to, ConvException;
import std.datetime.stopwatch : StopWatch;
import std.range : padLeft, retro, repeat;
import std.string : toUpper, strip, indexOf, lastIndexOf, leftJustify, isNumeric, stripRight, toStringz;
import std.traits : hasUDA, getUDAs, getSymbolsByUDA, arity;
import std.file : exists, FileException, isDir;
import std.path : dirName;

import core.runtime;
import core.sys.windows.windows;
import std.windows.syserror;

import program;
import utf8_slice;

// Attribute used to map from SQLPlus commands or variable names to 
// properties using the abbreviated forms as necessary.
public struct CommandName
{
    string ShortName;
    string LongName;
    
    public string CombinedName() 
    { 
        if (ShortName.length >= LongName.length)
            return ShortName;
        
        auto nameStart = ShortName.stripRight(" -");
        
        return nameStart ~ "[" ~ LongName[nameStart.length .. $] ~ "]";
    }
    
    public this(string shortName, string longName)
    {
        ShortName = shortName;
        LongName = longName;
    }
    
    public this(string name)
    {
        ShortName = name;
        LongName = name;
    }
}

// Attribute to display custom command or variable USAGE.
public struct CommandUsage
{
    string Text;
    
    public void Output()
    {
        Program.Buffer.AddText("USAGE: " ~ Text ~ lineEnding);
    }
    
    public static void OutputFor(alias member)()
    {
        getUDAs!(member, CommandUsage)[0].Output;
    }
}

public struct SubCommands
{
    string[] Commands;
    
    this(string[] commands ...)
    {
        Commands = commands.dup;
    }
}

// Attribute to display a single line command description.
public struct CommandSummary
{
    string Text;
}

// Attribute to display more detailed multi-line command guidance.  
// Do not duplicate information from CommandSummary.
public struct CommandRemarks
{
    string Text;
}

// TODO: Apply this in HELP.
// Attribute to designate a class that specifies subcommands.  
// This can be specified hierarchically for the HELP command.
public template CommandSubCommandClass(T) { }

public enum JustificationMode { Left, Centre, Right }

public abstract final class Commands
{
    // TODO Other commands to consider:
    // get
    // print
    // save
    // store
    // var      variable
    // whenever
    // doc      document  WTF?
    // password
    
    @CommandName("ABOUT")
    @CommandSummary("Displays program version information.")
    public static void About()
    {
        version (Windows)
        {
            import std.file;
            auto fileName = thisExePath;
            
            uint dummy;
            auto size = GetFileVersionInfoSizeA(fileName.ToCString, &dummy);
            
            auto versionInformation = new ubyte[size];
            if (!GetFileVersionInfoA(fileName.ToCString, 0, size, versionInformation.ptr))
                throw new RecoverableException("Call to Windows function GetFileVersionInfo failed.");
            
            auto text = appender!string;
            text.put(lineEnding);
            
            foreach (property; [
                "CompanyName",    
                "FileDescription",
                "FileVersion",    
                "LegalCopyright", 
                "OriginalFilename", 
                "ProductName",    
                "ProductVersion"])
            {
                uint length;
                char* buffer;
                
                if (!VerQueryValueA(versionInformation.ptr, (r"\StringFileInfo\080904b0\" ~ property).ToCString, cast(LPVOID*)&buffer, &length))
                    throw new RecoverableException("Call to Windows function VerQueryValue failed.");
                
                text.put(property.padLeft(' ', 20));
                text.put(": ");
                text.put(buffer.FromCString);
                text.put(lineEnding);
            }
            text.put(lineEnding);
            
            Program.Buffer.AddText(text.data);
        }
        else
            Program.Buffer.AddText("ABOUT command not implemented.");
    }
    
    @CommandName("ACC", "ACCEPT")
    @CommandUsage("ACC[EPT] user_variable [NUM[BER] | CHAR | DATE ] [FOR[MAT] format_specification] [DEF[AULT] default_value] [PROMPT promt_text | NOPR[OMPT]] [HIDE]")
    @CommandSummary("Get input from the user.  The value retrieved from the user is populated in a substitution variable.")
    @CommandRemarks("Currently the TYPE and FORMAT of the input is not validated.  This command supports providing those values for compatibility only.")
    public static void Accept(string remainingCommand)
    {
        // Stub for the help details.  This command is implemented in the interpreter directly.
    }
    
    @CommandName("CL", "CLEAR")
    @CommandUsage("CL[EAR] {BRE[AKS] | BUFF[ER] | COL[UMNS] | COMP[UTES] | SCR[EEN] | SQL | TIMI[NG]}")
    @SubCommands("BREAKS", "BUFFER ", "COLUMNS", "COMPUTES", "SCREEN", "SQL", "TIMING")
    @CommandSummary("Clears local client information or configuration.")
    public static void Clear(string remainingCommand)
    {
        if (Interpreter.StartsWithCommandWord!("BRE", "BREAKS")(remainingCommand))
        {
            Program.Settings.Breaks = [];
        }
        else if (Interpreter.StartsWithCommandWord!("BUF", "BUFFER")(remainingCommand) || 
                 Interpreter.StartsWithCommandWord!"SQL"(remainingCommand))
        {
            Program.Editor.ClearCommandHistory;
        }
        else if (Interpreter.StartsWithCommandWord!("COL", "COLUMNS")(remainingCommand))
        {
            UserDefinedColumn.Columns.clear;
        }
        else if (Interpreter.StartsWithCommandWord!("COMP", "COMPUTES")(remainingCommand))
        {
            Program.Settings.Computes = [];
        }
        else if (Interpreter.StartsWithCommandWord!("SCR", "SCREEN")(remainingCommand))
        {
            Program.Screen.showLogo = false;
            Program.Buffer.Clear;
        }
        else if (Interpreter.StartsWithCommandWord!("TIMI", "TIMING")(remainingCommand))
        {
            Program.Settings.Timers.clear;
        }
        else
        {
            Program.Buffer.AddText("Unknown CLEAR option." ~ lineEnding);
        }
    }
    
    
    enum columnUsage = CommandUsage(
        function()
        {
            auto text = "COL[UMN] column_name [option...]" ~ lineEnding ~ lineEnding ~ "  Where \"option\" is one or more of the following:" ~ lineEnding ~ lineEnding;
            
            static foreach (target; getSymbolsByUDA!(UserDefinedColumn, CommandName))                    
            {{
                static if (hasUDA!(target, CommandUsage))
                    enum name = getUDAs!(target, CommandUsage)[0].Text;
                else
                    enum name = __traits(identifier, target).CombinedName;
                
                text ~= "    " ~ name ~ lineEnding;
            }}
            
            return text;
        }());
    @CommandName("COL", "COLUMN")
    @columnUsage
    @CommandSummary("Defines column formatting.")
    @CommandSubCommandClass!UserDefinedColumn
    public static void Column(string remainingCommand)
    {
        if (remainingCommand.strip.length == 0)
        {
            auto text = appender!string;
            auto maxWidth = 0;
            
            foreach (name; UserDefinedColumn.Columns.keys)
                maxWidth = max(maxWidth, name.toUtf8Slice.intLength);
            
            if (maxWidth == 0)
            {
                Program.Buffer.AddText("  No columns defined.");
                return;
            }
            
            foreach (name, column; UserDefinedColumn.Columns)
            {
                text.put("  ");
                
                foreach (_; 0 .. maxWidth - name.toUtf8Slice.intLength)
                    text.put(" ");
                
                text.put(name);
                
                if (!column.IsEnabled)
                    text.put(" OFF");
                
                if (column.Heading.length > 0)
                {
                    const indentation = ' '.repeat(2 + maxWidth + (column.IsEnabled ? 0 : 4) + 9).array;
                    
                    text.put(" HEADING ");
                    text.put(replace(column.Heading, lineEnding, lineEnding ~ indentation));
                }
                
                if (column.FormatSpecifier.length > 0)
                {
                    text.put(" FORMAT ");
                    text.put(column.FormatSpecifier);
                }
                
                if (column.AliasedName.length > 0)
                {
                    text.put(" ALIAS ");
                    text.put(column.AliasedName);
                }
                
                if (column.NullPlaceHolder.length > 0)
                {
                    text.put(" NULL ");
                    text.put(column.NullPlaceHolder);
                }
                
                if (!column.IsVisible)
                    text.put(" NOPRINT");
                
                if (column.NullPlaceHolder.length > 0)
                {
                    text.put(" NULL ");
                    text.put(column.NullPlaceHolder);
                }
                
                final switch (column.Wrap) with (UserDefinedColumn.WrappingMode)
                {
                    case None:                                     break;
                    case Truncated:   text.put(" TRUNCATED");      break;
                    case ByWord:      text.put(" WORD_WRAPPED");   break;
                    case ByCharacter: text.put(" WRAPPED");        break;
                }
                
                final switch (column.Justify) with (JustificationMode)
                {
                    case Left:                                     break;
                    case Centre:      text.put(" JUSTIFY CENTRE"); break;
                    case Right:       text.put(" JUSTIFY RIGHT");  break;
                }
                
                if (column.NewValueVariableName.length > 0)
                {
                    text.put(" NEW_VALUE ");
                    text.put(column.NewValueVariableName);
                }
                
                if (column.OldValueVariableName.length > 0)
                {
                    text.put(" OLD_VALUE ");
                    text.put(column.OldValueVariableName);
                }
                
                text.put(lineEnding);
            }
            
            Program.Buffer.AddText(text.data);
            return;
        }
        
        auto name = OracleNames.RemoveQuotes(Interpreter.ConsumeToken(remainingCommand));
        auto column = UserDefinedColumn.Columns.require(name, new UserDefinedColumn());
        
        consume_options:
        while (true)
        {
            if (remainingCommand.length == 0)
                return;
            
            auto subCommand = remainingCommand;
            static foreach (command; getSymbolsByUDA!(UserDefinedColumn, CommandName))
                static foreach (commandName; getUDAs!(command, CommandName))
                    if (Interpreter.StartsWithCommandWord!(commandName.ShortName, commandName.LongName)(subCommand, remainingCommand))
                    {
                        enum parameterCount = arity!command;
                        
                        static if (parameterCount == 0) 
                            mixin("column.", __traits(identifier, command), ";");
                        else static if (parameterCount == 1)
                            mixin("column.", __traits(identifier, command), "(remainingCommand);");
                        else
                            static assert(false);
                        
                        continue consume_options;
                    }
            
            Program.Buffer.AddText("Unknown COLUMN option \"" ~ subCommand ~ "\".");
            return;
        }
    }
    
    
    @CommandName("BRE", "BREAK")
    @CommandUsage("BRE[AK] [ON {column_name | ROW | REPORT} [SKI[P] {lines_to_skip | PAGE}] [NODUP[LICATES] | DUP[LICATES]]...]")
    @CommandSummary("")
    public static void Break(string remainingCommand)
    {
        if (remainingCommand.length == 0)
        {
            auto text = appender!string;
            foreach (index, b; Program.Settings.Breaks)
            {
                if (index > 0)
                    text.put(lineEnding);
                
                text.put("  BREAK ON ");
                
                final switch (b.BreakType)
                {
                    case computes.BreakTypes.Column: text.put(b.ColumnName); break;
                    case computes.BreakTypes.Row:    text.put("ROW");        break;
                    case computes.BreakTypes.Report: text.put("REPORT");     break;
                }
                
                text.put(" SKIP ");
                
                final switch (b.SkipType) with (computes.SkipTypes)
                {
                    case Lines: text.put(b.LinesToSkip.to!string); break;
                    case Page:  text.put("PAGE");                  break;
                }
                
                if (b.PrintFollowingValue)
                    text.put(" DUPLICATES");
                else
                    text.put(" NODUPLICATES");
            }
            
            Program.Buffer.AddText(text.data);
            return;
        }
        
        Program.Settings.Breaks = [];
        
        while (remainingCommand.length > 0)
        {
            if (!Interpreter.StartsWithCommandWord!"ON"(remainingCommand, remainingCommand))
                throw new RecoverableException("Invalid BREAK command.  \"ON\" keyword expected.");
            
            auto breakType = computes.BreakTypes.Column;
            auto columnName = "";
            auto skipType = computes.SkipTypes.Lines;
            auto linesToSkip = 0;
            auto printFollowingValue = false;
            
            if (Interpreter.StartsWithCommandWord!"ROW"(remainingCommand, remainingCommand))
                breakType = computes.BreakTypes.Row;
            else if (Interpreter.StartsWithCommandWord!"REPORT"(remainingCommand, remainingCommand))
                breakType = computes.BreakTypes.Report;
            else
                columnName = OracleNames.ParseName(Interpreter.ConsumeToken(remainingCommand)).ObjectName;
            
            if (Interpreter.StartsWithCommandWord!("SKI", "SKIP")(remainingCommand, remainingCommand))
            {
                if (Interpreter.StartsWithCommandWord!("PAGE")(remainingCommand, remainingCommand))
                    skipType = computes.SkipTypes.Page;
                else
                    try
                        linesToSkip = Interpreter.ConsumeToken(remainingCommand).to!int;
                    catch (ConvException)
                        throw new RecoverableException("Invalid BREAK SKIP value.");
            }
            
            if (Interpreter.StartsWithCommandWord!("DUP", "DUPLICATES")(remainingCommand, remainingCommand))
                printFollowingValue = true;
            
            if (Interpreter.StartsWithCommandWord!("NODUP", "NODUPLICATES")(remainingCommand, remainingCommand))
                printFollowingValue = false;
            
            Settings.Breaks ~= computes.BreakDefinition(breakType, columnName, skipType, linesToSkip, printFollowingValue);
        }
    }
    
    
    @CommandName("ED", "EDIT")
    @CommandUsage("ED[IT] filename")
    @CommandSummary("Opens the selected file in an external editor.")
    @CommandRemarks("If no parameter was provided, this jumps to the previous command in the buffer.  Consider using Ctrl-Up and Ctrl-Down instead.")
    public static void EditFileDummySignature() { } // This is handled in the Editor and Interpreter classes.
    
    
    @CommandName("L", "LIST")
    @CommandUsage("L[IST] [{first_line_number | * | LAST}][ {last_line_number | * | LAST}]")
    @CommandSummary("Displays text lines from the previous command.")
    public static void ListDummySignature() { } // This is handled in the Editor class.
    
    
    @CommandName("A", "APPEND")
    @CommandUsage("A[PPEND] text")
    @CommandSummary("Appends text to the previous command.")
    @CommandRemarks("Consider using Ctrl-Up and Ctrl-Down to edit the previous command instead.")
    public static void AppendTextToBufferDummySignature() { } // This is handled in the Editor class.
    
    
    @CommandName("C", "CHANGE")
    @CommandUsage("C[HANGE] /old_text[/[new_text[/]]]")
    @CommandSummary("Replaces text in the previous command.")
    @CommandRemarks("Consider using Ctrl-Up and Ctrl-Down to edit the previous command instead.")
    public static void ChangeTextInBufferDummySignature() { } // This is handled in the Editor class.
        
    
    @CommandName("COMP", "COMPUTE")
    @CommandUsage("COMP[UTE] [function [LAB[EL] text]... OF column... ON {column... | REPORT | ROW}]" ~ lineEnding ~
                  "  Where function is one of {AVG | COU[NT] | MIN[IMUM] | MAX[IMUM] | NUM[BER] | SUM | STD | VAR[IANCE]}")
    @CommandSummary("")
    public static void Compute(string remainingCommand)
    {
        if (remainingCommand.length == 0)
        {
            auto text = appender!string;
            foreach (computeIndex, computeDefinition; Settings.Computes)
            {
                if (computeIndex > 0)
                    text.put(" ");
                
                foreach (computeFunction; computeDefinition.Functions)
                {
                    final switch (computeFunction.ComputeType) with (computes.Types)
                    {
                        case Average:           text.put("AVG");      break;
                        case Count:             text.put("COUNT");    break;
                        case Minimum:           text.put("MINIMUM");  break;
                        case Maximum:           text.put("MAXIMUM");  break;
                        case Number:            text.put("NUMBER");   break;
                        case Sum:               text.put("SUM");      break;
                        case StandardDeviation: text.put("STD");      break;
                        case Variance:          text.put("VARIANCE"); break;
                    }
                    
                    if (computeFunction.Label.length > 0)
                    {
                        text.put(" LABEL ");
                        text.put(computeFunction.Label);
                    }
                    
                    text.put(" ");
                }
                
                text.put("OF ");
                
                foreach (columnName; computeDefinition.ValuesColumnNames)
                {
                    text.put(columnName);
                    text.put(" ");
                }
                
                text.put("ON ");
                
                final switch (computeDefinition.BreakType) with (computes.BreakTypes)
                {
                    case Row:    text.put("ROW");    break;
                    case Report: text.put("REPORT"); break;
                    case Column: 
                    {
                        foreach (index, columnName; computeDefinition.BreakColumnNames)
                        {
                            if (index > 0)
                                text.put(" ");
                            
                            text.put(columnName);
                        }
                        
                        break;
                    }
                }
            }
            
            Program.Buffer.AddText(text.data);
            return;
        }
        
        computes.ComputeDefinition newComputeDefinition;
        
        while (remainingCommand.length > 0)
        {
            computes.ComputeFunction newFunction;
            
            if (Interpreter.StartsWithCommandWord!"AVG"(remainingCommand, remainingCommand))
                newFunction.ComputeType = computes.Types.Average;
            else if (Interpreter.StartsWithCommandWord!("COU", "COUNT")(remainingCommand, remainingCommand))
                newFunction.ComputeType = computes.Types.Count;
            else if (Interpreter.StartsWithCommandWord!("MIN", "MINIMUM")(remainingCommand, remainingCommand))
                newFunction.ComputeType = computes.Types.Minimum;
            else if (Interpreter.StartsWithCommandWord!("MAX", "MAXIMUM")(remainingCommand, remainingCommand))
                newFunction.ComputeType = computes.Types.Maximum;
            else if (Interpreter.StartsWithCommandWord!("NUM", "NUMBER")(remainingCommand, remainingCommand))
                newFunction.ComputeType = computes.Types.Number;
            else if (Interpreter.StartsWithCommandWord!"SUM"(remainingCommand, remainingCommand))
                newFunction.ComputeType = computes.Types.Sum;
            else if (Interpreter.StartsWithCommandWord!"STD"(remainingCommand, remainingCommand))
                newFunction.ComputeType = computes.Types.StandardDeviation;
            else if (Interpreter.StartsWithCommandWord!("VAR", "VARIANCE")(remainingCommand, remainingCommand))
                newFunction.ComputeType = computes.Types.Variance;
            else
                break;
            
            if (Interpreter.StartsWithCommandWord!("LAB", "LABEL")(remainingCommand, remainingCommand))
                newFunction.Label = Interpreter.ConsumeToken(remainingCommand);
            
            newComputeDefinition.Functions ~= newFunction;
        }
        
        if (newComputeDefinition.Functions.length == 0)
            throw new RecoverableException("Invalid COMP[UTE] function name.");
        
        if (!Interpreter.StartsWithCommandWord!"OF"(remainingCommand, remainingCommand))
            throw new RecoverableException("Invalid COMP[UTE] command.  Expected OF keyword.");
        
        while (remainingCommand.length > 0)
        {
            if (Interpreter.StartsWithCommandWord!"OF"(remainingCommand, remainingCommand))
                throw new RecoverableException("Invalid COMP[UTE] command.  OF keyword already specified.");
            
            if (Interpreter.StartsWithCommandWord!"ON"(remainingCommand, remainingCommand))
                break;
            
            newComputeDefinition.ValuesColumnNames ~= OracleNames.ParseName(Interpreter.ConsumeToken(remainingCommand)).ObjectName;
        }
        
        if (newComputeDefinition.ValuesColumnNames.length == 0)
            throw new RecoverableException("Invalid COMP[UTE] command.  Target columns not found after OF keyword.");
        
        while (remainingCommand.length > 0)
        {
            if (Interpreter.StartsWithCommandWord!"ON"(remainingCommand, remainingCommand))
                throw new RecoverableException("Invalid COMP[UTE] command.  ON keyword already specified.");
            
            if (Interpreter.StartsWithCommandWord!"ROW"(remainingCommand, remainingCommand))
                newComputeDefinition.BreakType = computes.BreakTypes.Row;
            else if (Interpreter.StartsWithCommandWord!"REPORT"(remainingCommand, remainingCommand))
                newComputeDefinition.BreakType = computes.BreakTypes.Report;
            else
                newComputeDefinition.BreakColumnNames ~= OracleNames.ParseName(Interpreter.ConsumeToken(remainingCommand)).ObjectName;
        }
        
        if (newComputeDefinition.BreakColumnNames.length == 0 && newComputeDefinition.BreakType == computes.BreakTypes.Column)
             new RecoverableException("Invalid COMP[UTE] command.  Break columns not found after ON keyword.");
        
        if (newComputeDefinition.BreakColumnNames.length > 0 && newComputeDefinition.BreakType != computes.BreakTypes.Column)
            new RecoverableException("Invalid COMP[UTE] command.  Break columns mixed with ROW or REPORT keyword.");
        
        Settings.Computes ~= newComputeDefinition;
    }
    
    @CommandName("COMMIT -", "COMMIT WORK")
    @CommandUsage("COMMIT [WORK] [COMMENT text | FORCE text [, system_change_number]]")
    @CommandSummary("Finalises the current database transaction.")
    public static void Commit(string remainingCommand)
    {
        // Stub for the help details.  This command is actually executed by Oracle and not SQLPlusX.
    }
    
    @CommandName("CONN", "CONNECT")
    @CommandUsage("CONN[ECT] {username/password@host | username/password | username@host | host}")
    @CommandSummary("Connects to a database.")
    @CommandRemarks("Prompts will be provided for missing properties.  If a null value is provided for a prompt, this cancels the command.")
    public static void Connect(string remainingCommand)
    {
        Program.Interpreter.BeginConnection(ConnectionDetails(remainingCommand));
    }
    
    @CommandName("DEF", "DEFINE")
    @CommandUsage("DEF[INE] [name [= value]]")
    @CommandSummary("Creates or lists local substitution variables.")
    @CommandRemarks("Substitution variables use a simple find and replace mechanism before the statement is sent to the database.  " ~ lineEnding ~ 
                    "They are simple, but do not have the security and performance guarantees of bind variables." ~ lineEnding ~ lineEnding ~ 
                    "DEFINE with no parameters lists all active substitution variables." ~ lineEnding ~ 
                    "DEFINE with a name only shows it's current value." ~ lineEnding)
    public static void Define(string remainingCommand)
    {
        auto name = Interpreter.ConsumeToken(remainingCommand).toUpper;
        if (name == "")
        {
            foreach (parameterName, value; Settings.SubstitutionVariables)
                Program.Buffer.AddText(parameterName ~ " = " ~ value);
            
            Program.Buffer.AddText("");
            return;
        }
        
        auto assignment = Interpreter.ConsumeToken(remainingCommand);
        if (assignment == "")
        {
            if (Settings.SubstitutionVariableExists(name))
                Program.Buffer.AddText(name ~ " = " ~ Settings.SubstitutionVariable(name) ~ lineEnding);
            else
                Program.Buffer.AddText(name ~ " is undefined" ~ lineEnding);
            
            return;
        }
        
        if (!assignment.startsWith('='))
        {
            Program.Buffer.AddText("DEFINE requires an equals sign (=)." ~ lineEnding);
            return;
        }
        
        string newValue = assignment[1 .. $].strip;
        if (newValue == "")
            newValue = Interpreter.ConsumeToken(remainingCommand);
        
        Settings.SetSubstitutionVariable(name, newValue);
        Program.AutoCompleteDatabase.AddDefine(name);
    }
    
    @CommandName("DEL")
    @CommandUsage("DEL [{first_line | * | LAST} [last_line | * | LAST}]]")
    @CommandSummary("Deletes one or more lines from the previous command.")
    @CommandRemarks("Consider using Ctrl-Up and Ctrl-Down to edit the previous command instead.")
    public static void DeleteLinesFromTheBufferDummySignature() { } // This is handled in the Editor class.
    
    @CommandName("GC")
    @CommandUsage("GC")
    @CommandSummary("Attempts to free up memory.")
    public static void GarbageCollection() 
    { 
        import core.memory;
        GC.collect;
    }
    
    @CommandName("DESC", "DESCRIBE")
    @CommandUsage("DESC[RIBE] [schema.]object_name[@database_link_name]")
    @CommandSummary("Describes a database object.")
    public static void Describe(string remainingCommand)
    {
        auto parameter = Interpreter.ConsumeToken(remainingCommand);
        if (parameter.length == 0 || remainingCommand.length > 0)
        {
            CommandUsage.OutputFor!Describe;
            return;
        }
        
        auto name = OracleNames.ParseName(parameter);
        
        if (name.ObjectName.length == 0)
        {
            CommandUsage.OutputFor!Describe;
            return;
        }
        
        Program.Database.Describe(name);
    }
    
    @CommandName("DISCON", "DISCONNECT")
    @CommandUsage("DISCON[NECT]")
    @CommandSummary("Disconnects from a database.")
    @CommandRemarks("A disconnection is implicit when issuing the CONNECT command, or closing the application.")
    public static void Disconnect(string remainingCommand)
    {
        Program.Database.Disconnect;
    }
    
    @CommandName("EXEC", "EXECUTE")
    @CommandUsage("EXEC[UTE] statement")
    @CommandSummary("Executes a PL/SQL expression (usually a procedure call).")
    @CommandRemarks("This is shorthand for \"BEGIN statement; END;\"")
    public static void ExecuteScript(string remainingCommand, int lineNumber)
    {
        Program.Database.Execute("BEGIN\n    " ~ remainingCommand ~ ";\nEND;\n", lineNumber);
    }
    
    @CommandName("EXIT")
    @CommandName("QUIT")
    @CommandUsage("EXIT | QUIT")
    @CommandSummary("Closes the client window.")
    @CommandRemarks("Closing the application window using the mouse or Alt-F4 will always cleanly disconnect the" ~ lineEnding ~ 
                    "session, so EXIT or QUIT is an optional method to exit.  There is no distinction between EXIT" ~ lineEnding ~ 
                    "and QUIT.  Any incomplete transaction is implicitly rolled back.")
    public static void Exit()
    {
        Program.Exit;
    }
    
    @CommandName("HELP")
    @CommandUsage("HELP [command]")
    @CommandSummary("Provides guidance on client commands.")
    @CommandRemarks("HELP with no parameters lists available commands." ~ lineEnding ~ 
                    "HELP on a specific command lists details of that command, a bit like this.")
    public static void Help(string remainingCommand)
    {
        if (remainingCommand.length == 0)
        {
            enum maxLength = function()
            {
                auto result = 0;
                
                foreach (command; getSymbolsByUDA!(Commands, CommandName))
                    foreach (commandName; getUDAs!(command, CommandName))
                        result = max(result, commandName.CombinedName.toUtf8Slice.intLength + 2);
                
                return result;
            }();
            
            static foreach (command; getSymbolsByUDA!(Commands, CommandName))
                static foreach (commandName; getUDAs!(command, CommandName))
                {
                    static if (hasUDA!(command, CommandSummary))
                        Program.Buffer.AddText("    " ~ (commandName.CombinedName ~ ": ").leftJustify(maxLength) ~ getUDAs!(command, CommandSummary)[0].Text);
                    else
                        Program.Buffer.AddText(commandName.CombinedName);
                }
            
            Program.Buffer.AddBlankLine;
            Program.Buffer.AddText("Use \"HELP command\" for usage and comments on a specific command.  For Example: \"HELP PROMPT\".");
            Program.Buffer.AddBlankLine;
            return;
        }
        
        auto subCommand = Interpreter.ConsumeToken(remainingCommand);
        
        static foreach (command; getSymbolsByUDA!(Commands, CommandName))
            static foreach (commandName; getUDAs!(command, CommandName))
                if (Interpreter.StartsWithCommandWord!(commandName.ShortName, commandName.LongName)(subCommand, remainingCommand))
                {
                    Program.Buffer.AddText("Command: ", FontStyle.Bold);
                    Program.Buffer.AddBlankLine;
                    Program.Buffer.AddText("    " ~ commandName.CombinedName);
                    Program.Buffer.AddBlankLine;
                    
                    static if (hasUDA!(command, CommandUsage))
                    {
                        Program.Buffer.AddText("Usage: ", FontStyle.Bold);
                        Program.Buffer.AddBlankLine;
                        
                        static foreach (usage; getUDAs!(command, CommandUsage))
                            Program.Buffer.AddText(cast(string)("    " ~ usage.Text.substitute!(lineEnding, lineEnding ~ "    ").to!string));
                        
                        Program.Buffer.AddBlankLine;
                    }
                    
                    static if (hasUDA!(command, CommandSummary))
                    {
                        Program.Buffer.AddText("Summary: ", FontStyle.Bold);
                        Program.Buffer.AddBlankLine;
                        
                        static foreach (summary; getUDAs!(command, CommandSummary))
                            Program.Buffer.AddText(cast(string)("    " ~ summary.Text.substitute!(lineEnding, lineEnding ~ "    ").to!string));
                        
                        Program.Buffer.AddBlankLine;
                    }
                    
                    static if (hasUDA!(command, CommandRemarks))
                    {
                        Program.Buffer.AddText("Remarks: ", FontStyle.Bold);
                        Program.Buffer.AddBlankLine;
                        
                        static foreach (remark; getUDAs!(command, CommandRemarks))
                            Program.Buffer.AddText("    " ~ remark.Text.substitute!(lineEnding, lineEnding ~ "    ").to!string);
                        
                        Program.Buffer.AddBlankLine;
                    }
                    
                    return;
                }
    }
    
    @CommandName("HO", "HOST")
    @CommandUsage("HO[ST] os_command")
    @CommandSummary("Execute an operating system command.")
    public static void Host(string remainingCommand) 
    {
        import std.process : executeShell, Config;
        immutable result = executeShell(remainingCommand, null, Config(Config.Flags.suppressConsole));
        
        // if (result.status != 0)
        //     Program.Buffer.AddText("Error code returned: " ~ result.status.to!string);
        // 
        if (result.output.length > 0)
            Program.Buffer.AddText(result.output);
    }
    
    @CommandName("RECON", "RECONNECT")
    @CommandUsage("RECON[NECT]")
    @CommandSummary("Reconnect the session using the previous connection details.")
    public static void Reconnect(string remainingCommand) 
    {
        Program.Database.Connect(Program.Database.connectionDetails);
    }
    
    @CommandName("REM", "REMARK")
    @CommandUsage("REM[ARK] comment")
    @CommandSummary("Comments are for readers and are ignored by the system.")
    public static void RemarkDummySignature(string remainingCommand) { }
    
    @CommandName("ROLL -", "ROLLBACK WORK")
    @CommandUsage("ROLL[BACK WORK] [TO [SAVEPOINT] savepoint_name | FORCE 'text']")
    @CommandSummary("Cancels the current transaction.")
    @CommandRemarks("If the previous statement was large or long running, a roll back operation may take a similar" ~ lineEnding ~ 
                    "time to complete.")
    public static void Rollback(string remainingCommand, int lineNumber)
    {
        Program.Database.Execute("ROLLBACK " ~ remainingCommand, lineNumber);
    }
    
    @CommandName("R", "RUN")
    @CommandUsage("R[UN]")
    @CommandSummary("Re-executes the last command.")
    public static void RunDummySignature(string remainingCommand) { } // Implemented in the Interpreter with "/".
    
    @CommandName("PAU", "PAUSE")
    @CommandUsage("PAU[SE] text")
    @CommandSummary("Awiting input with the specified prompt.")
    public static void Pause(string remainingCommand)
    {
        immutable prompt = remainingCommand.length > 0 ? remainingCommand : "Press any key to continue...";
        Program.Interpreter.SetAcceptPrompt(new AcceptPrompt("", prompt, AcceptPrompt.ContentType.PressAnyKey));
    }
    
    @CommandName("PRO", "PROMPT")
    @CommandUsage("PRO[MPT] text")
    @CommandSummary("Presents text to the user.")
    public static void Prompt(string remainingCommand)
    {
        Program.Buffer.AddText(remainingCommand.strip);
    }
    
    enum setUsage = CommandUsage(
        function() 
        {
            auto text = "SET [option [value]]" ~ lineEnding ~ lineEnding ~ "  Where \"option\" is one of the following:" ~ lineEnding ~ lineEnding;
            
            static foreach (target; getSymbolsByUDA!(Settings, Settings.SettableByTheSetCommand))                    
            {{
                static if (hasUDA!(target, CommandName))
                    enum name = getUDAs!(target, CommandName)[0].LongName;
                else
                    enum name = __traits(identifier, target).toUpper;
                
                text ~= "    " ~ name ~ lineEnding;
            }}
            
            return text;
        }());
    @CommandName("SET")
    @setUsage
    @CommandSummary("Sets client configuration options.")
    @CommandRemarks("SET with no parameters lists all client options." ~ lineEnding ~ 
                    "SET with a name only shows it's usage." ~ lineEnding)
    public static void Set(string remainingCommand)
    {
        if (remainingCommand == "")
        {
            CommandUsage.OutputFor!Set;
            return;
        }
        
        auto settingSubCommand = remainingCommand;
        static foreach (target; getSymbolsByUDA!(Settings, Settings.SettableByTheSetCommand))
        {{
            static if (hasUDA!(target, CommandName))
            {
                enum commandName = getUDAs!(target, CommandName)[0];
                enum shortName = commandName.ShortName;
                enum longName  = commandName.LongName;
            }
            else
            {
                enum shortName = __traits(identifier, target).toUpper;
                enum longName  = shortName;
            }
            
            if (Interpreter.StartsWithCommandWord!(shortName, longName)(settingSubCommand, remainingCommand))
            {
                if (remainingCommand.length > 0)
                    target(remainingCommand);
                else static if (hasUDA!(target, CommandUsage))
                    getUDAs!(target, CommandUsage)[0].Output;
                else
                    Program.Buffer.AddText("SET requires a value." ~ lineEnding);
                
                return;
            }
        }}
        
        auto name = Interpreter.ConsumeToken(settingSubCommand);
        Program.Buffer.AddText("Unknown SET option \"" ~ name ~ "\"." ~ lineEnding);
    }
    
    enum showUsage = CommandUsage(
        function() 
        {
            auto text = "SHO[W] {ALL | option}" ~ lineEnding ~ lineEnding ~ "  Where \"option\" is one of the following:" ~ lineEnding ~ lineEnding;
            
            static foreach (target; getSymbolsByUDA!(Settings, Settings.DisplayedByTheShowCommand))                    
            {{
                static if (hasUDA!(target, CommandName))
                    enum name = getUDAs!(target, CommandName)[0].CombinedName;
                else
                    enum name = __traits(identifier, target).toUpper;
                
                text ~= "    " ~ name ~ lineEnding;
            }}
            
            // TODO SHOW other items...
            text ~= "    ERR[ORS] [{FUNCTION | PROCEDURE | PACKAGE | PACKAGE BODY | DIMENSION | JAVA CLASS} [owner.]object_name]" ~ lineEnding ~ 
                    "    USER"                          ~ lineEnding ~ 
                 // "    LNO"                           ~ lineEnding ~  
                 // "    PNO"                           ~ lineEnding ~ 
                 // "    SGA"                           ~ lineEnding ~ 
                 // "    PARAMETER[S] [parameter_name]" ~ lineEnding ~ 
                 // "    REL[EASE]"                     ~ lineEnding ~ 
                 // "    REPF[OOTER]"                   ~ lineEnding ~ 
                 // "    REPH[EADER]"                   ~ lineEnding ~ 
                 // "    SPOO[L]"                       ~ lineEnding ~ 
                 // "    SQLCODE"                       ~ lineEnding ~ 
                    "    TTI[TLE]"                      ~ lineEnding ~ 
                    "    BTI[TLE]"                      ~ lineEnding;
            
            return text;
        }());
    
    @CommandName("SHO", "SHOW")
    @showUsage
    @SubCommands("ALL", "ERRORS", "USER", "TTITLE", "BTITLE")
    @CommandSummary("Shows client configuration options.")
    public static void Show(string remainingCommand)
    {
        if (remainingCommand == "")
        {
            Program.Buffer.AddText("SHOW requires an argument." ~ lineEnding);
            return;
        }
        
        if (Interpreter.StartsWithCommandWord!"ALL"(remainingCommand))
        {
            enum maxLength = function()
            {
                auto result = 0;
                
                foreach (target; getSymbolsByUDA!(Settings, Settings.DisplayedByTheShowCommand))
                    foreach (commandName; getUDAs!(target, CommandName))
                        result = max(result, commandName.CombinedName.toUtf8Slice.intLength + 2);
                
                return result;
            }();            
            
            auto text = appender!string;
            
            static foreach (target; getSymbolsByUDA!(Settings, Settings.DisplayedByTheShowCommand))                    
            {{
                static if (hasUDA!(target, CommandName))
                    enum targetName = getUDAs!(target, CommandName)[0].CombinedName;
                else
                    enum targetName = __traits(identifier, target).toUpper;
                
                text.put("    " ~ (targetName ~ ": ").leftJustify(maxLength));
                text.put(target(""));
                text.put(lineEnding);
            }}
            
            text.put(lineEnding);
            Program.Buffer.AddText(text.data);
            return;
        }
        
        string parameters;
        if (Interpreter.StartsWithCommandWord!("ERR", "ERRORS")(remainingCommand, parameters))
        {
            auto type = Interpreter.ConsumeToken(parameters).toUpper;
            auto name = Interpreter.ConsumeToken(parameters);
            
            Program.Database.ShowErrors(OracleNames.ParseName(name), type);
            return;
        }
        
        if (Interpreter.StartsWithCommandWord!("TTI", "TTITLE")(remainingCommand, parameters))
        {
            foreach (title; Program.Settings.Headers)
                Program.Buffer.AddText(title.Describe(Settings.PageTitleSpecification.Type.Header));
            
            return;
        }
        
        if (Interpreter.StartsWithCommandWord!("USER")(remainingCommand, parameters))
        {
            if (Program.Database.IsConnected)
                Program.Buffer.AddText("USER is " ~ Program.Database.connectionDetails.username);
            else
                Program.Buffer.AddText("No database connection");
            
            return;
        }
        
        if (Interpreter.StartsWithCommandWord!("BTI", "BTITLE")(remainingCommand, parameters))
        {
            foreach (title; Program.Settings.Footers)
                Program.Buffer.AddText(title.Describe(Settings.PageTitleSpecification.Type.Footer));
            
            return;
        }
        
        static foreach (target; getSymbolsByUDA!(Settings, Settings.DisplayedByTheShowCommand))
        {{
            static if (hasUDA!(target, CommandName))
            {
                enum commandName = getUDAs!(target, CommandName)[0];
                enum shortName = commandName.ShortName;
                enum longName  = commandName.LongName;
            }
            else
            {
                enum shortName = __traits(identifier, target).toUpper;
                enum longName  = shortName;
            }
            
            if (Interpreter.StartsWithCommandWord!(shortName, longName)(remainingCommand, remainingCommand))
            {
                Program.Buffer.AddText("    " ~ target(remainingCommand) ~ lineEnding);
                return;
            }
        }}
        
        auto name = Interpreter.ConsumeToken(remainingCommand);
        Program.Buffer.AddText("Unknown SHOW option \"" ~ name ~ "\"." ~ lineEnding);
    }
    
    @CommandName("SPO", "SPOOL")
    @CommandUsage("SPO[OL] {OFF | filename}")
    @SubCommands("OFF")
    @CommandSummary("Directs a copy of all screen output to a file.")
    @CommandRemarks("The dynamic SQLPlusX column sizing cannot apply to a spooled file if the memory threshold " ~ lineEnding ~ 
                    "is exceeded.  This means column sizing may work differently for large queries. " ~ lineEnding ~
                    "The SPOOL OUT option is not supported.")
    public static void Spool(string remainingCommand)
    {
        if (Interpreter.StartsWithCommandWord!"OUT"(remainingCommand))
        {
            Program.Buffer.AddText("SPOOL OUT is not supported." ~ lineEnding);
            return;
        }
        
        if (Interpreter.StartsWithCommandWord!"OFF"(remainingCommand))
        {
            Program.Buffer.StopSpooling;
            return;
        }
        
        auto filename = OracleNames.RemoveQuotes!false(Interpreter.ConsumeToken(remainingCommand));
        Program.Buffer.StartSpooling(filename);
    }                                                          
    
    @CommandName("RESET RENDERER")
    @CommandUsage("RESET RENDERER")
    @CommandSummary("Resets the renderer.  This exists for debugging purposes.")
    public static void ResetRenderer(string remainingCommand)
    {
        Program.Screen.CreateRenderer;
    }
    
    @CommandName("OPEN")
    @CommandUsage("OPEN path")
    @CommandSummary("Adds a directory path to the current paths list.")
    public static void OpenPath(string remainingCommand)
    {
        auto directory = OracleNames.RemoveQuotes!false(Interpreter.ConsumeToken(remainingCommand));
        
        if (directory.length == 0)
        {
            Program.Buffer.AddText("No directory specified." ~ lineEnding);
            return;
        }
        
        if (!AddPath(directory))
            Program.Buffer.AddText("Direcory not found: \"" ~ directory ~ "\"" ~ lineEnding);
    }
    
    @CommandName("SOURCE")
    @CommandUsage("SOURCE package | function | procedure | view")
    @CommandSummary("Extracts highlighted source code from the ALL_SOURCE or ALL_VIEWS data dictionary views.")
    public static void ShowSource(string remainingCommand)
    {
        const name = OracleNames.ParseName(Interpreter.ConsumeToken(remainingCommand));
        
        if (name.ObjectName.length == 0)
        {
            CommandUsage.OutputFor!ShowSource;
            return;
        }
        
        Program.Database.ShowSource(name);
    }
    
    @CommandName("START")
    @CommandUsage("{START | @ | @@} filename")
    @CommandSummary("Executes a script file.")
    public static void Start(string remainingCommand)
    {
        auto filename = OracleNames.RemoveQuotes!false(Interpreter.ConsumeToken(remainingCommand));
        
        if (filename.length == 0)
        {
            Program.Buffer.AddText("No file specified." ~ lineEnding);
            return;
        }
        
        auto fullPath = FindFile(filename);
        if (fullPath == "")
            Program.Buffer.AddText("File not found: " ~ filename ~ lineEnding);
        else
            Program.Interpreter.ProcessFile(fullPath, remainingCommand);
    }
    
    @CommandName("UNDEF", "UNDEFINE")
    @CommandUsage("UNDEF[INE] name1 [name2...]")
    @CommandSummary("Clears one or more substitution variables.")
    public static void Undefine(string remainingCommand)
    {
        auto parameters = remainingCommand.splitter(' ').filter!(p => p.length > 0);
        foreach (parameter; parameters)
        {
            auto name = parameter.toUpper;
            Settings.ClearSubstitutionVariable(name);
            Program.AutoCompleteDatabase.RemoveDefine(name);
        }
    }
    
    @CommandName("TIMI", "TIMING")
    @CommandUsage("TIMI[NG] [START timer_name | SHOW [timer_name] | STOP [timer_name]]")
    @SubCommands("START", "SHOW", "STOP")
    @CommandSummary("")
    public static void Timing(string remainingCommand)
    {
        auto mode = Interpreter.ConsumeToken(remainingCommand);
        auto timerName = Interpreter.ConsumeToken(remainingCommand);
        
        void showTimer(bool shouldStop)
        {
            void outputValue(string name, ref StopWatch timer)
            {
                Program.Buffer.AddText(name ~ ": " ~ timer.peek.DurationToPrettyString);
                
                if (shouldStop)
                {
                    timer.stop;
                    Program.Settings.Timers.remove(name);
                }
            }
            
            if (timerName.length == 0)
            {
                foreach (ref timer; Program.Settings.Timers.byKeyValue)
                    outputValue(timer.key, timer.value);
                
                return;
            }
            
            auto timeRef = timerName in Program.Settings.Timers;
            if (timeRef is null)
            {
                Program.Buffer.AddText("Timer \"" ~ timerName ~ "\" has not been started.");
                return;
            }
            
            outputValue(timerName, *timeRef);
        }
        
        switch (mode.toUpper)
        {
            case "START":
                
                if (timerName.length == 0)
                {
                    CommandUsage.OutputFor!Timing;
                    return;
                }
                
                Program.Settings.Timers.require(timerName);
                auto timer = timerName in Program.Settings.Timers;
                
                if (timer.running)
                    timer.stop;
                
                timer.reset;
                timer.start;
                
                return;
                
            case "SHOW":
                
                showTimer(false);
                return;
                
            case "STOP":
            
                showTimer(true);
                return;
                
            default:
                CommandUsage.OutputFor!Timing;
                return;
        }
    }
    
    @CommandName("TTI", "TTITLE")
    @CommandUsage("TTI[TLE] [OFF | ON] [COL x | S[KIP] x | TAB x | LE[FT] | CE[NTER] | R[IGHT] | BOLD | FOR[MAT] format spec | text | variable...]")
    @SubCommands("ON", "OFF", "COL", "SKIP", "TAB", "LEFT", "CENTER", "RIGHT", "BOLD", "FORMAT")
    @CommandSummary("Sets page header details.  Not implemented.")
    public static void SetHeader(ref string remainingCommand)
    {
        SetHeaderOrFooter!(Settings.PageTitleSpecification.Type.Header)(remainingCommand);
    }
    
    @CommandName("BTI", "BTITLE")
    @CommandUsage("BTI[TLE] [OFF | ON] [COL x | S[KIP] x | TAB x | LE[FT] | CE[NTER] | R[IGHT] | BOLD | FOR[MAT] format spec | text | variable...]")
    @SubCommands("ON", "OFF", "COL", "SKIP", "TAB", "LEFT", "CENTER", "RIGHT", "BOLD", "FORMAT")
    @CommandSummary("Sets page footer details.  Not implemented.")
    public static void SetFooter(ref string remainingCommand)
    {
        SetHeaderOrFooter!(Settings.PageTitleSpecification.Type.Footer)(remainingCommand);
    }
    
    public static void SetHeaderOrFooter(Settings.PageTitleSpecification.Type type)(ref string remainingCommand)
    {
        auto parameter = Interpreter.ConsumeToken(remainingCommand);
        
        if (Interpreter.StartsWithCommandWord!"OFF"(parameter) || 
            Interpreter.StartsWithCommandWord!"ON"(parameter))
        {
            final switch (type) with (Settings.PageTitleSpecification.Type)
            {
                case Header: Program.Settings.IsPageHeaderOnText = parameter; break;
                case Footer: Program.Settings.IsPageFooterOnText = parameter; break;
            }
            
            parameter = Interpreter.ConsumeToken(remainingCommand);
        }
        
        final switch (type) with (Settings.PageTitleSpecification.Type)
        {
            case Header: Program.Settings.Headers = []; break;
            case Footer: Program.Settings.Footers = []; break;
        }
        
        Settings.PageTitleSpecification title;
        
        while (parameter.length > 0)
        {
            auto parameterUpperCase = parameter.toUpper;
            
            if (Interpreter.StartsWithCommandWord!("COL")(parameterUpperCase))
            {
                parameter = Interpreter.ConsumeToken(remainingCommand);
                
                try
                    title.Column = parameter.to!int;
                catch (ConvException)
                    throw new RecoverableException("Invalid TTI[TLE] COL value.");
                
                parameter = Interpreter.ConsumeToken(remainingCommand);
            }
            if (Interpreter.StartsWithCommandWord!("S", "SKIP")(parameterUpperCase))
            {
                parameter = Interpreter.ConsumeToken(remainingCommand);
                
                try
                    title.SkipLinesCount = parameter.to!int;
                catch (ConvException)
                    throw new RecoverableException("Invalid TTI[TLE] S[KIP] value.");
                
                parameter = Interpreter.ConsumeToken(remainingCommand);
            }
            else if (Interpreter.StartsWithCommandWord!("TAB")(parameterUpperCase))
            {
                parameter = Interpreter.ConsumeToken(remainingCommand);
                
                try
                    title.Tab = parameter.to!int;
                catch (ConvException)
                    throw new RecoverableException("Invalid TTI[TLE] TAB value.");
                
                parameter = Interpreter.ConsumeToken(remainingCommand);
            }
            else if (Interpreter.StartsWithCommandWord!("LE", "LEFT")(parameterUpperCase))
            {
                title.Alignment = JustificationMode.Left;
                parameter = Interpreter.ConsumeToken(remainingCommand);
            }
            else if (Interpreter.StartsWithCommandWord!("CE", "CENTER")(parameterUpperCase))
            {
                title.Alignment = JustificationMode.Centre;
                parameter = Interpreter.ConsumeToken(remainingCommand);
            }
            else if (Interpreter.StartsWithCommandWord!("R", "RIGHT")(parameterUpperCase))
            {
                title.Alignment = JustificationMode.Right;
                parameter = Interpreter.ConsumeToken(remainingCommand);
            }
            else if (Interpreter.StartsWithCommandWord!("BOLD")(parameterUpperCase))
            {
                title.IsBold = true;
                parameter = Interpreter.ConsumeToken(remainingCommand);
            }
            else if (Interpreter.StartsWithCommandWord!("FOR", "FORMAT")(parameterUpperCase))
            {
                title.Format = Interpreter.ConsumeToken(remainingCommand);
                parameter = Interpreter.ConsumeToken(remainingCommand);
            }
            else
            {
                title.Text = parameter;
                
                final switch (type) with (Settings.PageTitleSpecification.Type)
                {
                    case Header: Program.Settings.Headers ~= title; break;
                    case Footer: Program.Settings.Footers ~= title; break;
                }
                
                title = Settings.PageTitleSpecification();
                
                parameter = Interpreter.ConsumeToken(remainingCommand);
            }
        }
    }
    
    public static bool AddPath(string directory)
    {
        try
        {
            if (!isDir(directory))
                return false;
        }
        catch (FileException)
        {
            return false;
        }
        
        Program.AutoCompleteDatabase.AddDirectory(directory);
        
        foreach (path; Settings.Paths)
            if (path == directory)
                return true;
        
        Settings.AddPath(directory);
        return true;
    }
    
    public static string FindFile(string filename)
    {
        // If this file was provided with a path, 
        // and it's new to us, add it to the collection.
        auto newPath = dirName(filename);
        if (newPath != ".")
        {
            if (!AddPath(newPath))
                return null;
            
            if (filename.exists)
            {
                if (filename.isDir)
                    throw new RecoverableException("File is a directory.");
                
                return filename;
            }
            
            filename ~= ".sql";
            if (filename.exists)
            {
                if (filename.isDir)
                    throw new RecoverableException("File is a directory.");
                
                return filename;
            }
        }
        
        foreach (path; Settings.Paths)
        {
            auto testPath = path ~ r"\" ~ filename;
            if (testPath.exists)
            {
                if (testPath.isDir)
                    throw new RecoverableException("File is a directory.");
                
                return testPath;
            }
            
            testPath ~= ".sql";
            if (testPath.exists)
            {
                if (testPath.isDir)
                    throw new RecoverableException("File is a directory.");
                
                return testPath;
            }
        }
        
        return null;
    }
}

public class UserDefinedColumn
{
    public static UserDefinedColumn[string] Columns;
    
    private bool isEnabled = true;
    public bool IsEnabled() const pure @nogc nothrow => isEnabled;
    
    @CommandName("ON")
    @CommandUsage("ON")
    @CommandSummary("Re-enables a disabled column.")
    public void Enable() { isEnabled = true; } 
    
    @CommandName("OFF")
    @CommandUsage("OFF")
    @CommandSummary("Disables column definition without losing the configuration details.")
    public void Disable() { isEnabled = false;} 
    
    
    private int width = -1;
    public int Width() const pure @nogc nothrow => width;
    
    private string formatSpecifier = "";
    public string FormatSpecifier() const pure @nogc nothrow => formatSpecifier;
    
    public bool isNumericFormat = false;
    
    @CommandName("FOR", "FORMAT")
    @CommandUsage("FOR[MAT] format")
    @CommandSummary("Sets the format of the column.")
    public void SetFormat(ref string remainingCommand) 
    {
        formatSpecifier = Interpreter.ConsumeToken(remainingCommand);
        
        if (formatSpecifier.startsWith('a', 'A') && formatSpecifier[1 .. $].isNumeric)
        {
            isNumericFormat = false;
        
            try
            {
                width = formatSpecifier[1 .. $].to!int;
                formatSpecifier = "";
            }
            catch (ConvException) { }
            return;
        }
        else
        {
            isNumericFormat = true;
        }
    }
    
    private string heading = "";
    public string Heading() const pure @nogc nothrow => heading;
    
    @CommandName("HEA", "HEADING")
    @CommandUsage("HEA[DING] heading")
    @CommandSummary("Set the title of the column.")
    public void SetHeading(ref string remainingCommand) 
    {
        heading = OracleNames.ParseName(Interpreter.ConsumeToken(remainingCommand)).ObjectName;
        
        if (heading.length > 2 && heading[0] == '\'' && heading[$ - 1] == '\'')
            heading = heading[1 .. $ - 1];
        
        heading = heading.replace("|", lineEnding);
    }
    
    private string aliasedName = "";
    public string AliasedName() const pure @nogc nothrow => aliasedName;
    
    @CommandName("ALI", "ALIAS")
    @CommandUsage("ALI[AS] alias")
    @CommandSummary("Set the alias of the column which can be used in a BREAK, COMPUTE or other COLUMN commands.")
    public void SetAliasedName(ref string remainingCommand) 
    {
        aliasedName = OracleNames.RemoveQuotes(Interpreter.ConsumeToken(remainingCommand));
        Columns[aliasedName] = this;
    }
    
    private string nullPlaceHolder = "";
    public string NullPlaceHolder() const pure => nullPlaceHolder;
    
    @CommandName("NUL", "NULL")
    @CommandUsage("NUL[L] place_holder")
    @CommandSummary("Sets the value to be presented in place of NULL.")
    public void SetNullPlaceHolder(ref string remainingCommand) 
    {
        nullPlaceHolder = Interpreter.ConsumeToken(remainingCommand);
    }
    
    private bool isVisible = true;
    public bool IsVisible() const pure @nogc nothrow => isVisible;
    
    @CommandName("NOPRI", "NOPRINT")
    @CommandUsage("NOPRI[NT]")
    @CommandSummary("Hides the column.")
    public void Hide() { isVisible = false; } 
    
    public enum WrappingMode { None, Truncated, ByWord, ByCharacter }
    
    private WrappingMode wrap = WrappingMode.None;
    public WrappingMode Wrap() const pure => wrap;
    
    @CommandName("TRU", "TRUNCATED")
    @CommandUsage("TRU[NCATED]")
    @CommandSummary("Sets the wrap mode to truncated.")
    @CommandRemarks("Specifies that a text too wide for this column is to be truncated." ~ lineEnding ~ 
                    "The full text will still be visible on mouse roll over.  This setting" ~ lineEnding ~ 
                    "disables wrapping.")
    public void DisableWrapping() { wrap = WrappingMode.Truncated; } 
    
    @CommandName("WOR", "WORD_WRAPPED")
    @CommandUsage("WOR[D_WRAPPED]")
    @CommandSummary("Sets the wrap mode to word wrapped.")
    @CommandRemarks("Specifies that a text too wide for this column is to be wrapped at word boundaries.")
    public void WordWrapped() { wrap = WrappingMode.ByWord; } 
    
    @CommandName("WRA", "WRAPPED")
    @CommandUsage("WRA[PPED]")
    @CommandSummary("Sets the wrap mode to word split.")
    @CommandRemarks("Specifies that a text too wide for this column is to be wrapped splitting words as necessary.")
    public void SplitWrapped() { wrap = WrappingMode.ByCharacter; } 
    
    @CommandName("CLE", "CLEAR")
    @CommandUsage("CLE[AR]")
    @CommandSummary("Removes all configured column formatting.")
    public void Clear()
    { 
        foreach (pair; Columns.byKeyValue)
            if (pair.value is this)
            {
                Columns.remove(pair.key);
                return;
            }
    }
    
    private JustificationMode justify = JustificationMode.Left;
    public JustificationMode Justify() const pure => justify;
    
    @CommandName("JUST", "JUSTIFY")
    @CommandUsage("JUST[IFY] {L[EFT] | C[ENTER] | C[ENTRE] | R[IGHT]}")
    @CommandSummary("Removes all configured column formatting.")
    public void SetJustify(ref string remainingCommand)
    {
        auto parameter = Interpreter.ConsumeToken(remainingCommand);
        
        if (parameter.length == 0)
            CommandUsage.OutputFor!SetJustify;
        else if (Interpreter.StartsWithCommandWord!("L", "LEFT")(parameter))
            justify = JustificationMode.Left;
        else if (Interpreter.StartsWithCommandWord!("C", "CENTER")(parameter) || 
                 Interpreter.StartsWithCommandWord!("C", "CENTRE")(parameter))
            justify = JustificationMode.Centre;
        else if (Interpreter.StartsWithCommandWord!("R", "RIGHT")(parameter))
            justify = JustificationMode.Right;
        else
            Program.Buffer.AddText("Unknown COLUMN JUSTIFY option \"" ~ parameter ~ "\"");
    }
    
    private string newValueVariableName = "";
    public string NewValueVariableName() => newValueVariableName;
    
    @CommandName("NEW_V", "NEW_VALUE")
    @CommandUsage("NEW_V[ALUE] variable")
    @CommandSummary("Set the variable in which to assign a value from this column.")
    public void SetNewValueVariableName(ref string remainingCommand) 
    {
        newValueVariableName = Interpreter.ConsumeToken(remainingCommand).toUpper;
    }
    
    private string oldValueVariableName = "";
    public string OldValueVariableName() => oldValueVariableName;
    
    @CommandName("OLD_V", "OLD_VALUE")
    @CommandUsage("OLD_V[ALUE] variable")
    @CommandSummary("Set the variable in which to assign a value from this column.")
    public void SetOldValueVariableName(ref string remainingCommand) 
    {
        oldValueVariableName = Interpreter.ConsumeToken(remainingCommand).toUpper;
    }
    
    @CommandName("LIKE", "LIKE")
    @CommandUsage("LIKE column")
    @CommandSummary("Copied formatted from the referenced column.")
    public void CopyFromColumn(ref string remainingCommand)
    {
        auto columnName = Interpreter.ConsumeToken(remainingCommand);
        
        if (columnName.length == 0)
        {
            CommandUsage.OutputFor!CopyFromColumn;
            return;
        }
        
        auto referencedColumn = columnName in Columns;
        
        if (referencedColumn is null)
        {
            Program.Buffer.AddText("Referenced column \"" ~ columnName ~ "\" not found.");
            return;
        }
        
        this.heading          = referencedColumn.heading;
        this.aliasedName      = referencedColumn.aliasedName;
        this.width            = referencedColumn.width;
        this.formatSpecifier  = referencedColumn.formatSpecifier;
        this.isNumericFormat  = referencedColumn.isNumericFormat;
        this.nullPlaceHolder  = referencedColumn.nullPlaceHolder;
        this.isVisible        = referencedColumn.isVisible;
        this.wrap             = referencedColumn.wrap;
        this.justify          = referencedColumn.justify;
    }
}
