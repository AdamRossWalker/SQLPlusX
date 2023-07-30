module settings;

import std.algorithm : max;
import std.array : appender;
import std.conv: to, ConvException;
import std.datetime.stopwatch : StopWatch;
import std.string : toUpper, strip, stripLeft, splitLines, indexOf, lastIndexOf, leftJustify, rightJustify;
import std.traits : EnumMembers;
import std.range : repeat;

import program;

public final class Settings 
{
    public enum DisplayedByTheShowCommand;
    public enum SettableByTheSetCommand;
    
    private static bool OnOffToBoolean(const string source)
    {
        if (source.toUpper == "ON")
            return true;
        
        if (source.toUpper == "OFF")
            return false;
        
        throw new RecoverableException("Invalid option.");
    }
    
    private static string BooleanToOnOff(const bool flag) { return flag ? "ON" : "OFF"; }
    
    private static string[] SubCommandsFromEnum(Enum, string[] extraCommands = null)()
        if (is(Enum == enum))
    {
        string[] subCommands;
        static foreach (value; EnumMembers!Enum)
            subCommands ~= value.to!string.toUpper;
        
        static foreach (value; extraCommands)
            subCommands ~= value.to!string.toUpper;
        
        return subCommands;
    }    
    
    // alias fromFieldFunction          = string function(string remainingCommand);
    // alias fromFieldFunctionWithField = string function(string value, string remainingCommand);
    // alias toFieldFunction            = void   function(string value);
    // alias toFieldFunctionWithField   = string function(string value);
    
    private mixin template Setting(
        string propertyName, 
        Type, 
        alias defaultValue, 
        string shortName, 
        string longName = shortName, 
        string usageText, 
        string[] setSubCommands, 
        string[] showSubCommands, 
        alias convertFieldToText, 
        alias convertTextToField)
    if (( is(Type == void) && 
          is(typeof(convertFieldToText) : string function(string remainingCommand)) &&
          is(typeof(convertTextToField) : void   function(string value))) || 
        (!is(Type == void) && 
          is(typeof(convertFieldToText) : string function(Type   value, string remainingCommand)) &&
          is(typeof(convertTextToField) : Type   function(string value))))
    {
        enum usage = CommandUsage(usageText);
        
        static if (!is(Type == void))
            mixin("public static Type " ~ propertyName ~ " = defaultValue;");
        
        @CommandName(shortName, longName)
        @DisplayedByTheShowCommand 
        @SubCommands(showSubCommands)
        static if (is(Type == void))
            mixin("public static string Get" ~ propertyName ~ "Value(string remainingCommand) { return convertFieldToText(remainingCommand); }");
        else
            mixin("public static string Get" ~ propertyName ~ "Value(string remainingCommand) { return convertFieldToText(" ~ propertyName ~ ", remainingCommand); }");
        
        @CommandName(shortName, longName)
        @usage
        @SettableByTheSetCommand 
        @SubCommands(setSubCommands)
        static if (is(Type == void))
            mixin("public static void Set" ~ propertyName ~ "Value(string value) { scope(failure) usage.Output; convertTextToField(value); }");
        else
            mixin("public static void Set" ~ propertyName ~ "Value(string value) { scope(failure) usage.Output; " ~ propertyName ~ " = convertTextToField(value); }");
    }

    private mixin template TextSetting(
        string propertyName, 
        string defaultValue, 
        string shortName, 
        string longName = shortName, 
        string usage)
    {
        mixin Setting!(propertyName, string, defaultValue, shortName, longName, usage, null, null, (string value, string remainingCommand) => value, (string value) => value);
    }

    private mixin template CharacterSetting(
        string propertyName, 
        string defaultValue, 
        string shortName, 
        string longName = shortName, 
        string usage)
    {
        mixin Setting!(propertyName, string, defaultValue, shortName, longName, usage, null, null, (string value, string remainingCommand) => value, 
        (string value) 
        { 
            if (value.length != 1)
                throw new RecoverableException("Invalid value.  This must be a single character.");
            
            return value;
        });
    }

    private mixin template NumberSetting(
        string propertyName, 
        Type, 
        Type defaultValue, 
        string shortName, 
        string longName = shortName, 
        string usage, 
        Type minValue = 0, 
        Type maxValue = Type.max)
    {
        mixin Setting!(propertyName, Type, defaultValue, shortName, longName, usage, null, null, 
            (Type value, string remainingCommand) => value.to!string, 
            (string value)
            {
                if (value.toUpper == "NONE")
                    return cast(Type)0;
                
                try
                {
                    auto i = value.to!Type;
                    
                    if (i < minValue || i > maxValue)
                        throw new RecoverableException("Invalid " ~ longName ~ " value.");
                    
                    return i;
                }
                catch (ConvException)
                    throw new RecoverableException("Invalid " ~ longName ~ " value.");
            });
    }
    
    private mixin template OnOffSetting(
        string propertyName, 
        bool defaultValue, 
        string shortName, 
        string longName = shortName, 
        string usage)
    {
        mixin Setting!(propertyName, bool, defaultValue, shortName, longName, usage, ["ON", "OFF"], null, (bool value, string remainingCommand) => Settings.BooleanToOnOff(value), (string value) => Settings.OnOffToBoolean(value));
    }
    
    
    //////// Paths ////////
    
    private static string[] paths;
    public static string[] Paths() @nogc nothrow { return paths; }
    
    public static void AddPath(string newPath)
    {
        paths ~= newPath;
    }
    
    static this()
    {
        import std.file : getcwd;
        AddPath(getcwd);
    }
    
    
    //////// Substitution Variables ////////
    
    private static string[string] substitutionVariables;
    
    public static const(string[string]) SubstitutionVariables() @nogc nothrow  { return substitutionVariables; }
    
    public static string SubstitutionVariable(string name) { return substitutionVariables.get(name, ""); }
    
    public static bool SubstitutionVariableExists(string name) @nogc nothrow { return cast(bool)(name in substitutionVariables); }
    
    public static void ClearSubstitutionVariable(string name) @nogc nothrow { substitutionVariables.remove(name); }
    
    public static void SetSubstitutionVariable(string name, string value) nothrow 
    {
        substitutionVariables[name] = value;
    }
    
    //////// Colors ////////
    
    mixin Setting!("Color", void, void, "COLOR", "COLOR", 
        "SET COLOR color_name r g b a", 
        SubCommandsFromEnum!(Screen.ColorNames), 
        SubCommandsFromEnum!(Screen.ColorNames), 
        (string remainingCommand)
        {
            auto text = appender!string;
            text.put(lineEnding);
            
            auto maxNameWidth = 0L;
            static foreach (colorName; EnumMembers!(Screen.ColorNames))
                maxNameWidth = max(maxNameWidth, colorName.to!string.length);
            
            text.put("    ");
            text.put(repeat(' ', maxNameWidth));
            text.put(" RED GRN BLU OPACITY\n");
            
            static foreach (colorName; EnumMembers!(Screen.ColorNames))
            {{
                enum name = colorName.to!string;
                if (Interpreter.StartsWithCommandWord!(name.toUpper)(remainingCommand) || remainingCommand.length == 0)
                {
                    
                    text.put("    ");
                    text.put(name.leftJustify(maxNameWidth));
                    text.put(" "); mixin("text.put(Program.Screen." ~ name ~ ".color.r.to!string.rightJustify(3));");
                    text.put(" "); mixin("text.put(Program.Screen." ~ name ~ ".color.g.to!string.rightJustify(3));");
                    text.put(" "); mixin("text.put(Program.Screen." ~ name ~ ".color.b.to!string.rightJustify(3));");
                    text.put(" "); mixin("text.put(Program.Screen." ~ name ~ ".color.a.to!string.rightJustify(3));");
                    text.put(lineEnding);
                }
            }}
            
            return text.data;
        }, 
        (string value)
        {
            const targetName = Interpreter.ConsumeToken(value);
            const rText = Interpreter.ConsumeToken(value);
            const gText = Interpreter.ConsumeToken(value);
            const bText = Interpreter.ConsumeToken(value);
            const aText = Interpreter.ConsumeToken(value);
            
            try
            {
                const r = rText.length > 0 ? rText.to!ubyte : 0;
                const g = gText.length > 0 ? gText.to!ubyte : 0;
                const b = bText.length > 0 ? bText.to!ubyte : 0;
                const a = aText.length > 0 ? aText.to!ubyte : 255;
                
                static foreach (colorName; EnumMembers!(Screen.ColorNames))
                {{
                    enum name = colorName.to!string;
                    if (Interpreter.StartsWithCommandWord!(name.toUpper)(targetName))
                       mixin("Program.Screen." ~ name ~ ".color(r, g, b, a);");
                }}
            }
            catch (ConvException)
            {
                throw new RecoverableException("USAGE: SET COLOR color_name r g b a.");
            }
        });
    
    
    //////// Timers ////////
    public static StopWatch[string] Timers;
    
    
    
    //////// Breaks ////////
    static BreakDefinition[] Breaks;
    
    
    //////// Computes ////////
    static computes.ComputeDefinition[] Computes;
    
    
    //////// Column Separator ////////
    mixin Setting!("ColumnSeparator", string, " ", "COLSEP", "COLSEP", 
        "SET COLSEP {OFF | \" \" | separator_character}", 
        ["OFF"], null, 
        (string value, string remainingCommand) => value, 
        (string value)
        {
            const newValue = Interpreter.ConsumeToken(value);
            
            if (Interpreter.StartsWithCommandWord!"OFF"(newValue))
                return " ";
            
            return OracleNames.RemoveQuotes(newValue);
        });
    
    
    //////// Record Separator Character ////////
    mixin CharacterSetting!("RecordSeparatorCharacter", " ", "RECSEPCHAR", "RECSEPCHAR", 
        "SET RECSEPCHAR separator_character");
    
    public static bool BlockTerminatorCharacterEnabled = true;
    public static string BlockTerminatorCharacter = ".";
    
    //////// Record Separator Character ////////
    mixin Setting!("BlockTerminatorCharacter", void, void, "BLO", "BLOCKTERMINATOR", 
        "SET [BLO]CKTERMINATOR {ON | OFF | terminator_character}", 
        ["ON", "OFF"], null, 
        (string remainingCommand) => BlockTerminatorCharacterEnabled ? BlockTerminatorCharacter : "OFF", 
        (string value)
        {
            if (Interpreter.StartsWithCommandWord!"ON"(value))
            {
                BlockTerminatorCharacterEnabled = true;
                return;
            }
            
            if (Interpreter.StartsWithCommandWord!"OFF"(value))
            {
                BlockTerminatorCharacterEnabled = false;
                return;
            }
            
            if (value.length != 1)
                throw new RecoverableException("Invalid value.  This must be a single character.");
            
            BlockTerminatorCharacter = value;
        });
    
    
    //////// Record Separator Mode ////////
    
    enum RecordSeparatorModes { Off, Wrapped, Each }
    
    mixin Setting!("RecordSeparatorMode", RecordSeparatorModes, RecordSeparatorModes.Off, "RECSEP", "RECSEP", 
        "SET RECSEP {WR[APPED] | EA[CH] | OFF}", 
        ["EACH", "OFF", "WRAPPED"], null, 
        (RecordSeparatorModes value, string remainingCommand)
        { 
            final switch (value) with (RecordSeparatorModes)
            {
                case Off:     return "OFF";
                case Wrapped: return "WRAPPED";
                case Each:    return "EACH";
            }
        }, 
        (string value) 
        { 
            auto parameter = Interpreter.ConsumeToken(value).toUpper;
            
            if (Interpreter.StartsWithCommandWord!("WR", "WRAPPED")(parameter))
                return RecordSeparatorModes.Wrapped;
            else if (Interpreter.StartsWithCommandWord!("EA", "EACH")(parameter))
                return RecordSeparatorModes.Each;
            else if (Interpreter.StartsWithCommandWord!"OFF"(parameter))
                return RecordSeparatorModes.Off;
            else
                throw new RecoverableException("Invalid column separator mode.");
        });
    
    
    //////// External Editor Path ////////
    mixin TextSetting!("ExternalEditorPath", "Notepad", "EDITOR", "EDITOR", 
        "SET EDITOR external_editor_path");
    
    
    //////// SQL Prompt ////////
    mixin Setting!("TerminalPrompt", void, void, "SQLP", "SQLPROMPT", 
        "SET SQLP[ROMPT] prompt_text", null, null, 
        (string remainingCommand) => Program.Editor.BasePrompt, 
        (string value) => Program.Editor.BasePrompt = value);
    
    mixin NumberSetting!("PromptOpacity", ubyte, 196, "PROMPTOPACITY", "PROMPTOPACITY", 
        "SET PROMPTOPACITY value" ~ lineEnding ~ lineEnding ~ "  Where value is between 0 and 255.", 0, 255);
    
    mixin NumberSetting!("PromptNumbersOpacity", ubyte, 127, "PROMPTNUMBERSOPACITY", "PROMPTNUMBERSOPACITY", 
        "SET PROMPTNUMBERSOPACITY value" ~ lineEnding ~ lineEnding ~ "  Where value is between 0 and 255.", 0, 255);
    
    mixin OnOffSetting!("IsPromptNumberingOn", true, "PROMPTNUMBERS", "PROMPTNUMBERS", 
        "SET PROMPTNUMBERS {ON | OFF}");
    
    //////// Editor File ////////
    mixin TextSetting!("EditFile", "SQLPlusXBuffer.sql", "EDITF", "EDITFILE", 
        "SET EDITF[ILE] filename" ~ lineEnding ~ lineEnding ~ "  Not implemented");
    
    public enum VerticalScrollBarModes { Simple, Narrow, Wide }
    
    //////// Scrollbar Map ////////
    mixin Setting!("VerticalScrollBarMode", VerticalScrollBarModes, VerticalScrollBarModes.Wide, "SCROLLBARMAP", "SCROLLBARMAP", 
        "SET SCROLLBARMAP {NARROW | WIDE | OFF}", 
        ["NARROW", "WIDE", "OFF"], null, 
        (VerticalScrollBarModes value, string remainingCommand)
        { 
            final switch (value) with (VerticalScrollBarModes)
            {
                case Simple: return "OFF";
                case Narrow: return "NARROW";
                case Wide:   return "WIDE";
            }
        }, 
        (string value) 
        { 
            auto parameter = Interpreter.ConsumeToken(value).toUpper;
            
            Program.Screen.InvalidateWindowSizes;
            
            if (Interpreter.StartsWithCommandWord!"NARROW"(parameter))
                return VerticalScrollBarModes.Narrow;
            else if (Interpreter.StartsWithCommandWord!"WIDE"(parameter))
                return VerticalScrollBarModes.Wide;
            else if (Interpreter.StartsWithCommandWord!"OFF"(parameter))
                return VerticalScrollBarModes.Simple;
            else
                throw new RecoverableException("Invalid scrollbar map mode.");
        });
    
    
    //////// Number Width ////////
    mixin NumberSetting!("NumberWidth", int, 10, "NUM", "NUMWIDTH", 
        "SET NUM[WIDTH] width" ~ lineEnding ~ lineEnding ~ "  Not implemented");
    
    
    //////// New Page ////////
    mixin NumberSetting!("NewPageLinesToPrint", int, 0, "NEWP", "NEWPAGE", 
        "SET NEWP[AGE] width" ~ lineEnding ~ lineEnding ~ "  Not implemented");
    
    
    //////// Describe ////////
    private static int describeDepth = int.max;
    public static int DescribeDepth() @nogc nothrow { return describeDepth; }
    
    private static bool isDescribeLineNumbersOn = false;
    public static bool IsDescribeLineNumbersOn() @nogc nothrow { return isDescribeLineNumbersOn; }
    
    private static bool isDescribeIndentOn = true;
    public static bool IsDescribeIndentOn() @nogc nothrow { return isDescribeIndentOn; }
    
    mixin Setting!("Describe", void, void, "DESCRIBE", "DESCRIBE", 
        "SET DESCRIBE [DEPTH {number_of_levels | ALL}] [LINENUM {ON | OFF}] [INDENT {ON | OFF}]" ~ lineEnding ~ lineEnding ~ "  Not all features implemented", 
        ["DEPTH", "DEPTH ALL", "LINENUM ON", "LINENUM OFF", "INDENT ON", "INDENT OFF"], 
        ["DEPTH", "DEPTH", "LINENUM", "LINENUM", "INDENT", "INDENT"], 
        (string remainingCommand) 
        {
            if (Interpreter.StartsWithCommandWord!"DEPTH"(remainingCommand))
                return "DEPTH " ~ (describeDepth == int.max ? "ALL" : describeDepth.to!string);
            
            if (Interpreter.StartsWithCommandWord!"LINENUM"(remainingCommand))
                return "LINENUM " ~ BooleanToOnOff(isDescribeLineNumbersOn);
                
            if (Interpreter.StartsWithCommandWord!"INDENT"(remainingCommand))
                return "INDENT " ~ BooleanToOnOff(isDescribeIndentOn);
            
            return "DEPTH " ~ (describeDepth == int.max ? "ALL" : describeDepth.to!string) ~ 
                  " LINENUM " ~ BooleanToOnOff(isDescribeLineNumbersOn) ~ 
                  " INDENT " ~ BooleanToOnOff(isDescribeIndentOn);
        }, 
        (string value)
        {
            auto parameter = Interpreter.ConsumeToken(value);
            
            if (Interpreter.StartsWithCommandWord!"DEPTH"(parameter))
            {
                parameter = Interpreter.ConsumeToken(value);
                
                if (parameter == "ALL")
                    describeDepth = int.max;
                else
                    try
                        describeDepth = parameter.to!int;
                    catch (ConvException)
                        throw new RecoverableException("Invalid DESCRIBE DEPTH size.");
                
                parameter = Interpreter.ConsumeToken(value);
            }
            
            if (Interpreter.StartsWithCommandWord!"LINENUM"(parameter))
            {
                parameter = Interpreter.ConsumeToken(value);
                isDescribeLineNumbersOn = OnOffToBoolean(parameter);
                parameter = Interpreter.ConsumeToken(value);
            }
            
            if (Interpreter.StartsWithCommandWord!"INDENT"(parameter))
            {
                parameter = Interpreter.ConsumeToken(value);
                isDescribeLineNumbersOn = OnOffToBoolean(parameter);
                parameter = Interpreter.ConsumeToken(value);
            }
            
            if (parameter.length > 0)
                throw new RecoverableException("Invalid DESCRIBE parameter.");
        });
    
    //////// Frame Counter ////////
    mixin OnOffSetting!("IsFrameCounterOn", false, "FRAME", "FRAMECOUNTER", 
        "SET FRAME[COUNTER] {ON | OFF}");
    
    
    //////// Logo ////////
    mixin Setting!("Logo", void, void, "LOGO", "LOGO", 
        "SET LOGO [{ON | OFF | timeout}]" ~ lineEnding ~ lineEnding ~ "  Where timeout in in seconds.", 
        ["ON", "OFF"], null, 
        (string remainingCommand) => "LOGO " ~ BooleanToOnOff(Program.Screen.showLogo), 
        (string value)
        {
            if (Interpreter.StartsWithCommandWord!"OFF"(value))
            {
                Program.Screen.showLogo = false;
                return;
            }
            
            Program.Screen.showLogo = true;
            
            ulong timeout = 5;
            try
                timeout = Interpreter.ConsumeToken(value).to!ulong;
            catch (ConvException) { }
            
            import std.datetime : dur;
            Program.Screen.logoTimeout = dur!"seconds"(timeout);
        });
    
    
    //////// Prompt Time ////////
    mixin Setting!("IsPromptTimeOn", void, void, "TI", "TIME", 
        "SET TI[ME] {ON | OFF}", 
        ["ON", "OFF"], null, 
        (string remainingCommand) => "TIME " ~ BooleanToOnOff(Program.Editor.IsPromptTimeOn), 
        (string value) => Program.Editor.IsPromptTimeOn = OnOffToBoolean(value));
        
    
    //////// Wrap ////////
    mixin OnOffSetting!("IsWrapOn", false, "WRA", "WRAP", 
        "SET WRA[P] {ON | OFF}" ~ lineEnding ~ lineEnding ~ "  Not implemented");
    
    
    //////// Trim Spool ////////
    mixin OnOffSetting!("IsTrimSpoolOn", false, "TRIMS", "TRIMSPOOL", 
        "SET TRIMS[POOL] {ON | OFF}" ~ lineEnding ~ lineEnding ~ "  Not implemented");
    
    
    //////// Trim Out ////////
    mixin OnOffSetting!("IsTrimOutOn", false, "TRIM", "TRIMOUT", 
        "SET TRIM[OUT] {ON | OFF}" ~ lineEnding ~ lineEnding ~ "  Not implemented");
    
    
    //////// Screen Dimensions ////////
    mixin Setting!("ScreenDimensions", void, void, "SCREENSIZE", "SCREENSIZE", 
        "SET SCREENSIZE {[FULL]SCREEN | MAX[IMIZE] | MIN[IMIZE] | RES[TORE] | {{LEFT | TOP | WIDTH | HEIGHT} size, ...}}", 
        ["FULLSCREEN", "MAXIMIZE", "MINIMIZE", "RESTORE", "LEFT", "TOP", "WIDTH", "HEIGHT"], 
        ["FULLSCREEN", "LEFT", "TOP", "WIDTH", "HEIGHT"], 
        (string remainingCommand)
        {
            if (Interpreter.StartsWithCommandWord!("FULL", "FULLSCREEN")(remainingCommand))
                return "FULLSCREEN " ~ BooleanToOnOff(Program.Screen.IsFullScreen);
            
            if (Interpreter.StartsWithCommandWord!"LEFT"(remainingCommand))
                return "LEFT " ~ Program.Screen.windowLeft.to!string;
            
            if (Interpreter.StartsWithCommandWord!"TOP"(remainingCommand))
                return "TOP " ~ Program.Screen.windowTop.to!string;
            
            if (Interpreter.StartsWithCommandWord!"WIDTH"(remainingCommand))
                return "WIDTH " ~ Program.Screen.windowWidth.to!string;
            
            if (Interpreter.StartsWithCommandWord!"HEIGHT"(remainingCommand))
                return "HEIGHT " ~ Program.Screen.windowHeight.to!string;
            
            return "LEFT "    ~ Program.Screen.windowLeft  .to!string ~ 
                  " TOP "    ~ Program.Screen.windowTop   .to!string ~ 
                  " WIDTH "  ~ Program.Screen.windowWidth .to!string ~ 
                  " HEIGHT " ~ Program.Screen.windowHeight.to!string;
        }, 
        (string remainingCommand)
        {
            auto seenAtLeastOneParameter = false;
            auto left   = Program.Screen.windowLeft;
            auto top    = Program.Screen.windowTop;
            auto width  = Program.Screen.windowWidth;
            auto height = Program.Screen.windowHeight;
            
            while (true)
            {
                auto parameter = Interpreter.ConsumeToken(remainingCommand);
                if (parameter.length == 0)
                {
                    if (!seenAtLeastOneParameter)
                        throw new RecoverableException("Missing SET SCREENSIZE parameter.");
                    
                    break;
                }
                
                if (Interpreter.StartsWithCommandWord!("FULL", "FULLSCREEN")(parameter))
                {
                    Program.Screen.IsFullScreen = true;
                    return;
                }
                
                Program.Screen.IsFullScreen = false;
                
                if (Interpreter.StartsWithCommandWord!("MAX", "MAXIMIZE")(parameter))
                {
                    Program.Screen.MaximizeWindow;
                    return;
                }
                
                if (Interpreter.StartsWithCommandWord!("MIN", "MINIMIZE")(parameter))
                {
                    Program.Screen.MinimizeWindow;
                    return;
                }
                
                if (Interpreter.StartsWithCommandWord!("RES", "RESTORE")(parameter))
                {
                    Program.Screen.RestoreWindow;
                    return;
                }
                
                int value;
                try
                    value = Interpreter.ConsumeToken(remainingCommand).to!int;
                catch (ConvException)
                    throw new RecoverableException("Invalid SET SCREENSIZE parameter size.");
                
                seenAtLeastOneParameter = true;
                
                if      (Interpreter.StartsWithCommandWord!"LEFT"  (parameter)) left   = value;
                else if (Interpreter.StartsWithCommandWord!"TOP"   (parameter)) top    = value;
                else if (Interpreter.StartsWithCommandWord!"WIDTH" (parameter)) width  = value;
                else if (Interpreter.StartsWithCommandWord!"HEIGHT"(parameter)) height = value;
                else
                    throw new RecoverableException("Invalid SET SCREENSIZE parameter.");
            }
            
            Program.Screen.SetWindowSize(left, top, width, height);
        });
    
    
    //////// Server Output ////////
    
    enum ServerOutputModes { Truncated, Wrapped, WordWrapped }

    private static bool isServerOutputOn = false;
    public static bool IsServerOutputOn() @nogc nothrow { return isServerOutputOn; }
    
    private static int serverOutputSize = 1000000;
    public static int ServerOutputSize() @nogc nothrow { return serverOutputSize; }
    
    private static ServerOutputModes serverOutputMode = ServerOutputModes.Truncated;
    public static ServerOutputModes ServerOutputMode() @nogc nothrow { return serverOutputMode; }
    
    mixin Setting!("ServerOutput", void, void, "SERVEROUT", "SERVEROUTPUT", 
        "SET SERVEROUT[PUT] {ON | OFF} [SIZE {buffer_size | UNLIMITED}] [FOR[MAT] {WRA[PPED] | WOR[D_WRAPPED] | TRU[NCATED]}" ~ lineEnding ~ lineEnding ~ "  Line management not implemented", 
        ["ON", "OFF", "SIZE", "FORMAT"], null, 
        (string remainingCommand) => 
            BooleanToOnOff(isServerOutputOn) ~ 
            " SIZE " ~ (ServerOutputSize == -1 ? "UNLIMITED" : ServerOutputSize.to!string) ~ 
            " FORMAT " ~ ()
            {
                final switch (serverOutputMode) with (ServerOutputModes)
                {
                    case Truncated:   return "TRUNCATED";
                    case Wrapped:     return "WRAPPED";
                    case WordWrapped: return "WORD_WRAPPED";
                }
            }(), 
        (string value)
        {
            scope (success)
            {
                if (isServerOutputOn)
                    Program.Database.Execute("BEGIN DBMS_OUTPUT.ENABLE(" ~ (serverOutputSize == -1 ? "NULL" : serverOutputSize.to!string) ~ "); END;", 0, true);
                else
                    Program.Database.Execute("BEGIN DBMS_OUTPUT.DISABLE; END;", 0, true);
            }
            
            auto parameter = Interpreter.ConsumeToken(value);
            isServerOutputOn = OnOffToBoolean(parameter);
            
            parameter = Interpreter.ConsumeToken(value);
            if (parameter.length == 0)
                return;
            
            if (parameter.toUpper == "SIZE")
            {
                parameter = Interpreter.ConsumeToken(value);
                
                if (parameter.toUpper == "UNLIMITED")
                    serverOutputSize = -1;
                else
                    try
                        serverOutputSize = parameter.to!int;
                    catch (ConvException)
                        throw new RecoverableException("Invalid NUM[WIDTH] size.");
                
                parameter = Interpreter.ConsumeToken(value);
            }
            
            if (parameter.length == 0)
                return;
            
            if (Interpreter.StartsWithCommandWord!("FOR", "FORMAT")(parameter))
            {
                parameter = Interpreter.ConsumeToken(value);
                
                if (Interpreter.StartsWithCommandWord!("TRU", "TRUNCATED")(parameter))
                    serverOutputMode = ServerOutputModes.Truncated;
                else if (Interpreter.StartsWithCommandWord!("WOR", "WORD_WRAPPED")(parameter))
                    serverOutputMode = ServerOutputModes.WordWrapped;
                else if (Interpreter.StartsWithCommandWord!("WRA", "WRAPPED")(parameter))
                    serverOutputMode = ServerOutputModes.Wrapped;
                else
                    throw new RecoverableException("Invalid SERVEROUT[PUT] FOR[MAT] option.");
                
                parameter = Interpreter.ConsumeToken(value);
            }
            
            if (parameter.length == 0)
                return;
            
            throw new RecoverableException("Invalid SERVEROUT[PUT] option.");
        });
    
    
    //////// Long ////////
    mixin OnOffSetting!("IsSnapCursorOn", true, "SNAPCURSOR", "SNAPCURSOR", 
        "SET SNAPCURSOR {ON | OFF}");
    
    
    //////// Long ////////
    mixin NumberSetting!("LongStringMaxLength", int, 80, "LONG", "LONG", 
        "SET LONG maximum_long_column_width" ~ lineEnding ~ lineEnding ~ "  Not implemented");
    
    
    //////// Long Chunk Size ////////
    mixin NumberSetting!("LongChunkSize", int, 80, "LONGC", "LONGCHUNKSIZE", 
        "SET LONGCHUNKSIZE charaters_per_fetch" ~ lineEnding ~ lineEnding ~ "  Not implemented");
    
    
    //////// Array Size ////////
    mixin NumberSetting!("ArraySize", int, 15, "ARRAY", "ARRAYSIZE", 
        "SET ARRAY[SIZE] records_per_fetch" ~ lineEnding ~ lineEnding ~ "  Not implemented");
    
    
    //////// Document ////////
    mixin OnOffSetting!("IsDocumentOn", false, "DOC", "DOCUMENT", 
        "SET DOC[DOCUMENT] {ON | OFF}" ~ lineEnding ~ lineEnding ~ "  Not implemented");
    
    
    //////// Heading ////////
    mixin OnOffSetting!("IsHeadingOn", false, "HEA", "HEADING", 
        "SET HEA[DING] {ON | OFF}" ~ lineEnding ~ lineEnding ~ "  Not implemented");
    
    
    //////// Verify ////////
    mixin OnOffSetting!("IsVerifyOn", false, "VER", "VERIFY", 
        "SET VER[IFY] {ON | OFF}");
    
    
    //////// Timing ////////
    mixin OnOffSetting!("IsTimingOn", false, "TIMI", "TIMING", 
        "SET TIMI[NG] {ON | OFF}");
    
    
    //////// Terminal Output ////////
    mixin OnOffSetting!("IsTerminalOutputOn", false, "TERM", "TERMOUT", 
        "SET TERM[OUT] {ON | OFF}" ~ lineEnding ~ lineEnding ~ "  Not implemented");
    
    
    //////// SQL Number ////////
    mixin OnOffSetting!("IsSqlNumberOn", false, "SQLN", "SQLNUMBER", 
        "SET SQLN[UMBER] {ON | OFF}" ~ lineEnding ~ lineEnding ~ "  Not implemented");
    
    
    //////// Auto Commit ////////
    mixin OnOffSetting!("IsAutoCommitOn", false, "AUTO", "AUTOCOMMIT", 
        "SET AUTO[COMMIT] {ON | OFF | IMMEDIATE | n}" ~ lineEnding ~ lineEnding ~ "  Where n is the number of statements to commit together." ~ lineEnding ~ "  Not implemented");
    
    
    //////// Feedback ////////
    private static auto isFeedbackOn = true;
    public static auto IsFeedbackOn() @nogc nothrow { return isFeedbackOn; }
    
    private static auto feedbackTheshold = 1;
    public static auto FeedbackTheshold() @nogc nothrow { return feedbackTheshold; }
    
    mixin Setting!("Feedback", void, void, "FEED", "FEEDBACK", 
        "SET FEEDBACK  ON | OFF | n}" ~ lineEnding ~ lineEnding ~ "  Where n is the minimum number of rows to report.", 
        ["ON", "OFF"], null, 
        (string remainingCommand) => BooleanToOnOff(isFeedbackOn) ~ " (" ~ feedbackTheshold.to!string ~ ")", 
        (string value)
        {
            if (value.toUpper == "ON")
            {
                isFeedbackOn = true;
                feedbackTheshold = 0;
            }
            else if (value.toUpper == "OFF")
            {
                isFeedbackOn = false;
            }
            else
            {
                isFeedbackOn = true;
                try
                    feedbackTheshold = value.to!int;
                catch (ConvException)
                    throw new RecoverableException("Invalid feedback option.");
            }
        });
    
    
    //////// Scan lines ////////
    mixin Setting!("IsShowingScanLines", void, void, "SCANLINES", "SCANLINES", 
        "SET SCANLINES {ON | OFF}", 
        ["ON", "OFF"], null, 
        (string remainingCommand) => BooleanToOnOff(Program.Screen.IsShowingScanLines), 
        (string value) => Program.Screen.IsShowingScanLines = OnOffToBoolean(value));
    
    
    //////// Page Size ////////
    mixin NumberSetting!("PageSize", int, -1, "PAGES", "PAGESIZE", 
        "SET PAGES[IZE] n" ~ lineEnding ~ lineEnding ~ "  Not implemented", -1);
    
    
    //////// Line Size ////////
    mixin NumberSetting!("LineSize", int, 80, "LIN", "LINESIZE", 
        "SET LIN[ESIZE]");
    
    
    //////// Define ////////
    private static bool substitutionEnabled = true;
    public static bool SubstitutionEnabled() @nogc nothrow { return substitutionEnabled; }
    
    private static char substitutionCharacter = '&';
    public static char SubstitutionCharacter() @nogc nothrow { return substitutionCharacter; }
    
    mixin Setting!("Define", void, void, "DEF", "DEFINE", 
        "SET DEF[INE] {ON | OFF | c}", 
        ["ON", "OFF"], null, 
        (string remainingCommand) => substitutionCharacter.to!string, 
        (string value)
        {
            if (value.toUpper == "ON")
                substitutionEnabled = true;
            else if (value.toUpper == "OFF")
                substitutionEnabled = false;
            else if (value.length != 1)
                throw new RecoverableException("Define must be a single character.");
            else 
                substitutionCharacter = value[0];
        });
    
    
    //////// Echo ////////
    mixin OnOffSetting!("IsEchoScriptCommands", false, "ECHO", "ECHO", 
        "SET ECHO {ON | OFF}");
    
    
    //////// Underline ////////
    private static auto isUnderlineEnabled = true;
    public static auto IsUnderlineEnabled() @nogc nothrow { return isUnderlineEnabled; }
    
    private static auto underlineCharacter = '-';
    public static auto UnderlineCharacter() @nogc nothrow { return underlineCharacter; }
    
    mixin Setting!("UnderlineCharacter", void, void, "UND", "UNDERLINE", 
        "SET UNDERLINE {ON | OFF | c}", 
        ["ON", "OFF"], null, 
        (string remainingCommand) => isUnderlineEnabled ? underlineCharacter.to!string : "OFF", 
        (string value)
        {
            if (value.toUpper == "ON")
                isUnderlineEnabled = true;
            else if (value.toUpper == "OFF")
                isUnderlineEnabled = false;
            else if (value.length != 1)
                throw new RecoverableException("Underline must be a single character.");
            else
                underlineCharacter = value[0];
        });
    
    
    //////// SQL Warnings ////////
    mixin OnOffSetting!("IsShowingSqlWarnings", true, "SQLWARNINGS", "SQLWARNINGS", 
        "SET SQLWARNINGS {ON | OFF}");
    
    
    //////// Stars Count ////////
    mixin Setting!("StarCount", void, void, "STARCOUNT", "STARCOUNT", 
        "SET STARCOUNT 0 - 10000", null, null, 
        (string remainingCommand) => Program.Screen.StarsCount.to!string, 
        (string value)
        {
            try
            {
                auto count = value.to!int;
                
                if (count > 10000)
                    throw new RecoverableException("Invalid number of stars.");
                
                Program.Screen.StarsCount = count;
            }
            catch (ConvException)
                throw new RecoverableException("Invalid number of stars.");
        });
    
    
    //////// Font Size ////////
    mixin Setting!("FontSize", void, void, "FONTSIZE", "FONTSIZE", 
        "SET FONTSIZE 5 - 100", null, null, 
        (string remainingCommand) => Program.Screen.FontSize.to!string, 
        (string value)
        {
            try
            {
                auto size = value.to!uint; 
                
                if (size < 5 || size > 100)
                    throw new RecoverableException("Invalid font size.");
                
                Program.Screen.FontSize = size;
            }
            catch (ConvException)
                throw new RecoverableException("Invalid font size.");
        });
    
    
    //////// Font Draw Mode ////////
    mixin Setting!("FontDrawMode", void, void, "FONTDRAWMODE", "FONTDRAWMODE", 
        "SET FONTDRAWMODE {SOLID, BLEND, SHADE}", 
        ["SOLID", "BLEND", "SHADE"], null, 
        (string remainingCommand) => 
            " FONTDRAWMODE " ~ ()
            {
                final switch (Program.Screen.FontDrawMode) with (Program.Screen.FontDrawModes)
                {
                    case Solid: return "SOLID";
                    case Blend: return "BLEND";
                    case Shade: return "SHADE";
                }
            }(),         
        (string value)
        {
            auto parameter = Interpreter.ConsumeToken(value);
            
            if      (Interpreter.StartsWithCommandWord!("SOLID")(parameter)) Program.Screen.FontDrawMode = Program.Screen.FontDrawModes.Solid;
            else if (Interpreter.StartsWithCommandWord!("BLEND")(parameter)) Program.Screen.FontDrawMode = Program.Screen.FontDrawModes.Blend;
            else if (Interpreter.StartsWithCommandWord!("SHADE")(parameter)) Program.Screen.FontDrawMode = Program.Screen.FontDrawModes.Shade;
            else 
                throw new RecoverableException("Invalid FONTDRAWMODE option.");
        });
    
    //////// Font Hint////////
    mixin Setting!("FontHint", void, void, "FONTHINT", "FONTHINT", 
        "SET FONTHINT {NONE, NORMAL, LIGHT, MONO, LIGHTSUBPIXEL}", 
        ["NONE", "NORMAL", "LIGHT", "MONO", "LIGHTSUBPIXEL"], null, 
        (string remainingCommand) => 
            " FONTHINT " ~ ()
            {
                final switch (Program.Screen.FontHint) with (Program.Screen.FontHints)
                {
                    case None:          return "NONE";
                    case Normal:        return "NORMAL";
                    case Light:         return "LIGHT";
                    case Mono:          return "MONO";
                    case LightSubPixel: return "LIGHTSUBPIXEL";
                }
            }(),         
        (string value)
        {
            auto parameter = Interpreter.ConsumeToken(value);
            
            if      (Interpreter.StartsWithCommandWord!("NONE"         )(parameter)) Program.Screen.FontHint = Program.Screen.FontHints.None;
            else if (Interpreter.StartsWithCommandWord!("NORMAL"       )(parameter)) Program.Screen.FontHint = Program.Screen.FontHints.Normal;
            else if (Interpreter.StartsWithCommandWord!("LIGHT"        )(parameter)) Program.Screen.FontHint = Program.Screen.FontHints.Light;
            else if (Interpreter.StartsWithCommandWord!("MONO"         )(parameter)) Program.Screen.FontHint = Program.Screen.FontHints.Mono;
            else if (Interpreter.StartsWithCommandWord!("LIGHTSUBPIXEL")(parameter)) Program.Screen.FontHint = Program.Screen.FontHints.LightSubPixel;
            else
                throw new RecoverableException("Invalid FONTHINT option.");
        });
    
    
    //////// Page Header ////////
    
    public struct PageTitleSpecification
    {
        enum Type { Header, Footer }
        
        auto Column = 0;
        auto SkipLinesCount = 0;
        auto Tab = 0;
        auto Alignment = JustificationMode.Centre;
        auto IsBold = false;
        auto Format = "";
        auto Text = "";
        
        string Describe(Type type)
        {
            auto text = appender!string;
            
            final switch (type) with (Type)
            {
                case Header:  text.put("TTITLE ");  break;
                case Footer:  text.put("BTITLE ");  break;
            }
            
            if (Column         > 0) {  text.put("COL ");   text.put(Column        .to!string); }
            if (SkipLinesCount > 0) {  text.put("SKIP ");  text.put(SkipLinesCount.to!string); }
            if (Tab            > 0) {  text.put("TAB ");   text.put(Tab           .to!string); }
            
            final switch (Alignment) with (JustificationMode)
            {
                case Left:    text.put("LEFT ");    break;
                case Centre:  text.put("CENTER ");  break;
                case Right:   text.put("RIGHT ");   break;
            }
            
            if (IsBold)
                text.put("BOLD ");
            
            if (Format.length > 0) { text.put("FORMAT ");  text.put(Format); }
            if (Text.length   > 0) {                       text.put(Text); }
            
            return text.data;
        }
    }
    
    private static bool isPageHeaderOn = false;
    public static bool IsPageHeaderOn() @nogc nothrow { return isPageHeaderOn; }
    
    public static string IsPageHeaderOnText() { return BooleanToOnOff(isPageHeaderOn); }
    public static void IsPageHeaderOnText(string value) { isPageHeaderOn = OnOffToBoolean(value); }
    
    public static PageTitleSpecification[] Headers;
    
    
    //////// Page Footer ////////
    
    private static bool isPageFooterOn = false;
    public static bool IsPageFooterOn() @nogc nothrow { return isPageFooterOn; }
    
    public static string IsPageFooterOnText() { return BooleanToOnOff(isPageFooterOn); }
    public static void IsPageFooterOnText(string value) { isPageFooterOn = OnOffToBoolean(value); }    
    
    public static PageTitleSpecification[] Footers;
    
    
    //////// Theme ////////
    mixin Setting!("Theme", InterfaceTheme, InterfaceTheme.SqlPlus, "THEME", "THEME", 
        function()
        {
            auto text = "SET THEME {";
            
            foreach (index, member; EnumMembers!InterfaceTheme)
                text ~= member.to!string ~ " | ";
            
            text ~= "Random}";
            
            return text;
        }(), 
        SubCommandsFromEnum!(InterfaceTheme, ["RANDOM"]), 
        null, 
        (InterfaceTheme value, string remainingCommand) => value.to!string, 
        (string value)
        {
            auto theme = ()
            {
                switch (value.toUpper)
                {
                    case "RANDOM":
                        import std.random : uniform;
                        return cast(InterfaceTheme)(uniform!"[]"(InterfaceTheme.min, InterfaceTheme.max));
                    
                    static foreach (caseTheme; EnumMembers!InterfaceTheme)
                        case caseTheme.to!string.toUpper:
                            return caseTheme;
                    
                    default:
                        throw new RecoverableException("Unknown theme option.");
                }
            }();
            
            Program.Screen.SetTheme(theme);
            return theme;
        });
     
    
    // Other SQLPlus variables to consider:
    // 
    // appinfo is OFF and set to "SQL*Plus"
    // autoprint OFF
    // autorecovery OFF
    // autotrace OFF
    // blockterminator "." (hex 2e)
    // cmdsep OFF
    // compatibility version NATIVE
    // concat "." (hex 2e)
    // copycommit 0
    // COPYTYPECHECK is ON
    // embedded OFF
    // escape OFF
    // escchar OFF
    // exitcommit ON
    // flagger OFF
    // flush ON
    // headsep "|" (hex 7c)
    // instance "local"
    // linesize 80
    // lno 17
    // loboffset 1
    // logsource ""
    // markup HTML OFF HEAD "
    // REFORMAT OFF
    // null ""
    // numformat ""
    // PAUSE is OFF
    // pno 0
    // release 1102000200
    // repfooter OFF and is NULL
    // repheader OFF and is NULL
    // securedcol is OFF
    // shiftinout INVISIBLE
    // showmode OFF
    // sqlblanklines OFF
    // sqlcase MIXED
    // sqlcode 0
    // sqlcontinue "> "
    // sqlpluscompatibility 11.2.0
    // sqlprefix "#" (hex 23)
    // sqlterminator ";" (hex 3b)
    // suffix "sql"
    // tab ON
    // USER is "TESTDB"
    // xmloptimizationcheck OFF
    // errorlogging is OFF
}