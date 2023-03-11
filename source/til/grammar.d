module til.grammar;

import std.algorithm : among, canFind;
import std.conv : to;
import std.math : pow;

import til.conv;
import til.exceptions;
import til.nodes;
import til.procedures;


const EOL = '\n';
const SPACE = ' ';
const TAB = '\t';
const PIPE = '|';
const STOPPERS = [')', '>', ']', '}'];

// Integers units:
uint[char] units;

static this()
{
    units['K'] = 1;
    units['M'] = 2;
    units['G'] = 3;
}

class IncompleteInputException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

class Parser
{
    size_t index = 0;
    string code;
    bool eof = false;

    size_t line = 1;
    size_t col = 0;

    string[] stack;

    this(string code)
    {
        this.code = code;
    }

    // --------------------------------------------
    Program run()
    {
        try
        {
            return consumeProgram();
        }
        catch(Exception ex)
        {
            throw new Exception(
                "Error at line " ~
                line.to!string ~
                ", column " ~
                col.to!string ~
                ": " ~ ex.to!string
            );
        }
    }

    char currentChar()
    {
        return code[index];
    }
    char lastChar()
    {
        return code[index - 1];
    }
    char consumeChar()
    {
        if (eof)
        {
            throw new IncompleteInputException("Code input already ended");
        }
        debug {
            if (code[index] == EOL)
            {
                stderr.writeln("consumed: eol");
            }
            else
            {
                stderr.writeln("consumed: '", code[index], "'");
            }
        }
        auto result = code[index++];
        col++;

        if (result == EOL)
        {
            col = 0;
            line++;
            debug {stderr.writeln("== line ", line, " ==");}
        }

        if (index >= code.length)
        {
            debug {stderr.writeln("CODE ENDED");}
            this.eof = true;
            index--;
        }

        return result;
    }

    // --------------------------------------------
    void consumeWhitespaces()
    {
        if (eof) return;

        int counter = 0;

        bool consumed = true;

        while (consumed && !eof)
        {
            consumed = false;
            // Common whitespaces:
            while (isWhitespace && !eof)
            {
                consumeChar();
                consumed = true;
                counter++;
            }
            // Comments:
            if (currentChar == '#')
            {
                consumeLine();
                consumed = true;
                counter++;
            }
        }
        debug {
            if (counter)
            {
                stderr.writeln("whitespaces (" ~ counter.to!string ~ ")");
            }
        }
    }
    void consumeLine()
    {
        do
        {
            consumeChar();
        }
        while (currentChar != EOL);
        consumeChar();  // consume the eol.
    }
    void consumeWhitespace()
    {
        assert(isWhitespace);
        debug {stderr.writeln("whitespace");}
        consumeChar();
    }
    void consumeSpace()
    {
        debug {stderr.writeln("  SPACE");}
        assert(currentChar == SPACE);
        consumeChar();
    }
    bool isWhitespace()
    {
        return cast(bool)currentChar.among!(SPACE, TAB, EOL);
    }
    bool isSignificantChar()
    {
        if (this.eof) return false;
        return !isWhitespace();
    }
    bool isEndOfLine()
    {
        return eof || currentChar == EOL;
    }
    bool isStopper()
    {
        return (eof
                || currentChar == '}' || currentChar == ']'
                || currentChar == ')' || currentChar == '>');
    }

    // --------------------------------------------
    // Nodes
    Program consumeProgram()
    {
        auto p = new Program();

        // There can't be any whitespaces before
        // the first section!
        auto section_path = consumeSectionHeader();
        if (section_path.length != 1)
        {
            throw new Exception(
                "Invalid syntax: expecting 'program' section header"
            );
        }
        if (section_path[0].toString() != "program")
        {
            throw new Exception(
                "Invalid syntax: expecting 'program' section header"
            );
        }
        auto metadataSection = consumeSection();
        p.full_name = metadataSection["full_name"].toString();
        p.description = metadataSection["description"].toString();

        consumeWhitespaces();

        // Now read the other sections:
        while (!eof)
        {
            section_path = consumeSectionHeader();
            if (section_path[0].toString()[0] == '#')
            {
                // Consume the section ignoring it completely
                while (true)
                {
                    auto c = consumeChar();
                    if (c == EOL)
                    {
                        if (currentChar == '[')
                        {
                            break;
                        }
                    }
                }
                continue;
            }
            auto subDict = p.navigateTo(section_path[0..$-1]);
            subDict[section_path[$-1].toString()] = consumeSection();
            consumeWhitespaces();
        }

        return p;
    }
    Items consumeSectionHeader()
    {
        Items items;

        debug {
            stderr.writeln("   consumeSectionHeader: " ~ currentChar);
        }

        auto opener = consumeChar();
        if (opener != '[')
        {
            throw new Exception(
                "Invalid syntax: expecting section header"
            );
        }

        string token;
        while (currentChar != ']')
        {
            auto c = consumeChar();
            if (c == '/')
            {
                if (token.length == 0)
                {
                    throw new Exception(
                        "Invalid section header at line "
                        ~ line.to!string
                    );
                }
                items ~= new String(token);
                token = "";
            }
            else
            {
                token ~= c;
            }
        }
        if (token.length)
        {
            items ~= new String(token);
        }

        auto closer = consumeChar();
        auto newline = consumeChar();

        return items;
    }
    Dict consumeSection()
    {

        debug {
            stderr.writeln("consumeSection");
        }
        // No whitespaces after the header!

        /*
        We can have comment lines immediately
        after the section header and immediately
        before the section dict:
        */
        while (currentChar == '#')
        {
            consumeLine();
        }

        // key simple_value
        // key { document_dict }
        auto dict = consumeSectionDict();

        consumeWhitespaces();

        debug {
            stderr.writeln(" consumeSection: currentChar: " ~ currentChar);
        }
        // After a newline, it's
        // i) another section header or
        // ii) a SubProgram.
        if (currentChar != '[')
        {
            auto subprogram = consumeSubProgram();
            dict["subprogram"] = subprogram;
        }

        return dict;
    }
    SectionDict consumeSectionDict()
    {
        debug {
            stderr.writeln("consumeSectionDict");
        }
        /*
        section dict:
        key value EOL
        key value EOL
        key value EOL
        EOL  <-- this marks the end.
        */
        auto dict = new SectionDict();

        while (currentChar != EOL)
        {
            // Dict content may be indented...
            consumeWhitespaces();

            if (currentChar == '}')
            {
                consumeChar(); // }
                break;
            }

            auto key = consumeAtom();

            consumeWhitespace();

            debug {
                stderr.writeln(" consumeSectionDict: key: " ~ key.toString());
                stderr.writeln("             currentChar: " ~ currentChar);
            }

            Item value;
            if (currentChar == '{')
            {
                consumeChar();
                consumeWhitespaces();
                value = consumeSectionDict();
            }
            else
            {
                value = consumeItem();
            }
            dict[key.toString()] = value;

            auto newline = consumeChar();
            if (newline != EOL)
            {
                throw new Exception(
                    "Expecting newline after section dict entry, found `"
                    ~ newline
                    ~ "`"
                );
            }
        }

        debug {
            stderr.writeln(" /consumeSectionDict: currentChar: " ~ currentChar);
        }
        return dict;
    }
    SectionDict consumeInlineSectionDict()
    {
        /*
             \ /
              v
        set d <{
            key1 value1
            key2 value2
        }>
        */
        debug {
            stderr.writeln("consumeInlineSectionDict: " ~ currentChar);
        }
        auto inlineOpener = consumeChar();
        auto opener = consumeChar();
        assert(opener == '{');
        consumeWhitespaces();
        auto dict = consumeSectionDict();
        /*
        consumeSectionDict will already consume the closing '}'
        */
        // XXX: this consumeSectionDict function is kinda weird...
        auto inlineCloser = consumeChar();

        return dict;
    }

    SubProgram consumeSubProgram()
    {
        Pipeline[] pipelines;

        debug {
            stderr.writeln("consumeSubProgram: " ~ currentChar);
        }

        consumeWhitespaces();

        while(!isStopper)
        {
            // TODO: check if we are creating EMPTY Pipelines
            // for each new empty line in the code...
            pipelines ~= consumePipeline();

            /*
            Pipelines can't begin with '['. If that's
            the case, we just found a new section header.
            (Besides, no need to consumeWhitespaces here,
            since section headers always begin in col 0. We
            only use it to consume empty lines.)
            */
            consumeWhitespaces();

            if (currentChar == '[')
            {
                break;
            }
        }

        return new SubProgram(pipelines);
    }

    Pipeline consumePipeline()
    {
        CommandCall[] commands;

        debug {
            stderr.writeln("   consumePipeline: ", currentChar);
        }

        consumeWhitespaces();

        while (!isEndOfLine && !isStopper)
        {
            auto command = consumeCommandCall();
            commands ~= command;

            if (currentChar == PIPE) {
                consumeChar();
                consumeSpace();
            }
            else
            {
                break;
            }
        }

        if (isEndOfLine && !eof) consumeChar();
        return new Pipeline(commands);
    }

    CommandCall consumeCommandCall()
    {
        debug {
            stderr.writeln("   consumeCommandCall: ", currentChar);
        }

        // inline transform/foreach:
        if (currentChar == '{')
        {
            CommandCall nextCall = foreachInline();
            if (!isEndOfLine)
            {
                debug {
                    stderr.writeln("     transform.inline");
                }
                // Whops! It's not a foreach.inline, but a transform.inline!
                nextCall.name = "transform.inline";
                consumeWhitespaces();
            }
            else
            {
                debug {
                    stderr.writeln("     foreach.inline");
                }
            }
            return nextCall;
        }

        NameAtom commandName = cast(NameAtom)consumeAtom();
        Item[] arguments;

        // That is: if the command HAS any argument:
        while (true)
        {
            if (currentChar == EOL)
            {
                consumeChar();
                consumeWhitespaces();
                if (currentChar == '.')
                {
                    consumeChar();
                    consumeSpace();
                    arguments ~= consumeItem();
                    continue;
                }
                else
                {
                    break;
                }
            }
            else if (currentChar == SPACE)
            {
                consumeSpace();
                if (currentChar.among!('}', ']', ')', '>', PIPE))
                {
                    break;
                }
                arguments ~= consumeItem();
            }
            else
            {
                break;
            }
        }

        return new CommandCall(commandName.toString(), arguments);
    }
    CommandCall foreachInline()
    {
        return new CommandCall("foreach.inline", [consumeSubList()]);
    }

    Item consumeItem()
    {
        debug {
            stderr.writeln("   consumeItem: ", currentChar);
        }
        switch(currentChar)
        {
            case '{':
                return consumeSubString();
            case '[':
                return consumeExecList();
            case '(':
                return consumeSimpleList();
            case '<':
                return consumeInlineSectionDict();
            case '"':
            case '\'':
                return consumeString();
            default:
                return consumeAtom();
        }
    }

    Item consumeSubString()
    {
        /*
        set s {{
            something and something else
        }}
        // $s -> "something and something else"
        */

        auto open = consumeChar();
        assert(open == '{');

        if (currentChar == '{')
        {
            // It's a subString!

            // Consume the current (and second) '{':
            consumeChar();

            // Consume any opening newlines and spaces:
            consumeWhitespaces();

            char[] token;
            while (true)
            {
                if (currentChar == '}')
                {
                    consumeChar();
                    if (currentChar == '}')
                    {
                        consumeChar();

                        // Find all the blankspaces in the end of the string:
                        size_t end = token.length;
                        do
                        {
                            end--;
                        }
                        while (token[end].among!(SPACE, TAB, EOL));

                        return new String(token[0..end+1].to!string);
                    }
                    else
                    {
                        token ~= '}';
                    }
                }
                else if (currentChar == '\n')
                {
                    token ~= consumeChar();
                    consumeWhitespaces();
                    continue;
                }
                token ~= consumeChar();
            }
        }
        else
        {
            auto subprogram = consumeSubProgram();
            auto close = consumeChar();
            assert(close == '}');
            return subprogram;
        }
    }

    SubProgram consumeSubList()
    {
        auto open = consumeChar();
        assert(open == '{');
        auto subprogram = consumeSubProgram();
        auto close = consumeChar();
        assert(close == '}');

        return subprogram;
    }

    ExecList consumeExecList()
    {
        auto open = consumeChar();
        assert(open == '[');
        auto subprogram = consumeSubProgram();
        auto close = consumeChar();
        assert(close == ']');

        return new ExecList(subprogram);
    }

    SimpleList consumeSimpleList()
    {
        Item[] items;
        auto open = consumeChar();
        assert(open == '(');

        if (currentChar != ')')
        {
            items ~= consumeItem();
        }
        while (currentChar != ')')
        {
            consumeWhitespaces();
            items ~= consumeItem();
        }

        auto close = consumeChar();
        assert(close == ')');

        return new SimpleList(items);
    }

    String consumeString()
    {
        auto opener = consumeChar();
        assert(opener == '"' || opener == '\'');

        char[] token;
        StringPart[] parts;
        bool hasSubstitution = false;

        ulong index = 0;
        while (currentChar != opener)
        {
            if (currentChar == '$')
            {
                if (token.length)
                {
                    parts ~= new StringPart(token, false);
                    token = new char[0];
                }

                // Consume the '$':
                consumeChar();

                // Current part:
                bool enclosed = (currentChar == '{');
                if (enclosed) consumeChar();

                while ((currentChar >= 'a' && currentChar <= 'z')
                        || (currentChar >= '0' && currentChar <= '9')
                        || currentChar == '.' || currentChar == '_')
                {
                    token ~= consumeChar();
                }

                if (token.length != 0)
                {
                    if (enclosed)
                    {
                        assert(currentChar == '}');
                        consumeChar();
                    }

                    parts ~= new StringPart(token, true);
                    hasSubstitution = true;
                }
                else
                {
                    throw new Exception(
                        "Invalid string: "
                        ~ "parts:" ~  parts.to!string
                        ~ "; token:" ~ cast(string)token
                        ~ "; length:" ~ token.length.to!string
                    );
                }
                token = new char[0];
            }
            else if (currentChar == '\\')
            {
                // Discard the escape charater:
                consumeChar();

                // And add the next char, whatever it is:
                switch (currentChar)
                {
                    // XXX: this cases could be written at compile time.
                    case 'b':
                        token ~= '\b';
                        consumeChar();
                        break;
                    case 'n':
                        token ~= '\n';
                        consumeChar();
                        break;
                    case 'r':
                        token ~= '\r';
                        consumeChar();
                        break;
                    case 't':
                        token ~= '\t';
                        consumeChar();
                        break;
                    // TODO: \u1234
                    default:
                        token ~= consumeChar();
                }
            }
            else
            {
                token ~= consumeChar();
            }
        }

        // Adds the eventual last part (in
        // simple strings it will be
        // the first part, always:
        if (token.length)
        {
            parts ~= new StringPart(token, false);
        }

        auto closer = consumeChar();
        assert(closer == opener);

        if (hasSubstitution)
        {
            debug {stderr.writeln("new SubstString: ", parts);}
            return new SubstString(parts);
        }
        else if (parts.length == 1)
        {
            debug {stderr.writeln("new String: ", parts);}
            return new String(parts[0].value);
        }
        else
        {
            return new String("");
        }
    }

    Item consumeAtom()
    {
        char[] token;

        bool isNumber = true;
        bool isSubst = false;
        uint dotCounter = 0;

        // `$x`
        if (currentChar == '$')
        {
            isNumber = false;
            isSubst = true;
            // Do NOT add `$` to the SubstAtom.
            consumeChar();
        }
        // -2
        else if (currentChar == '-')
        {
            token ~= consumeChar();
        }

        // The rest:
        while (!eof && !isWhitespace)
        {
            if (currentChar >= '0' && currentChar <= '9')
            {
            }
            else if (currentChar == '.')
            {
                dotCounter++;
            }
            /*
            else if (currentChar == '(')
            {
                // $(1 + 2 + 4)
                SimpleList list = consumeSimpleList();
                return list.infixProgram();
            }
            */
            else if (currentChar >= 'A' && currentChar <= 'Z')
            {
                uint* p = (currentChar in units);
                if (p is null)
                {
                    throw new Exception(
                        "Invalid character in name: "
                        ~ cast(string)token
                        ~ currentChar.to!string
                    );
                }
                else
                {
                    // Do not consume the unit.
                    break;
                }
            }
            else if (token.length && STOPPERS.canFind(currentChar))
            {
                break;
            }
            else
            {
                isNumber = false;
            }
            token ~= consumeChar();
        }

        debug {stderr.writeln(" token: ", token);}

        string s = cast(string)token;
        debug {stderr.writeln(" s: ", s);}

        // 123
        // .2
        if (isNumber)
        {

            // .
            // (a dot, alone)
            // -
            // (a dash, alone)
            if (s == "-" || s == ".")
            {
                return new NameAtom(s);
            }
            else if (dotCounter == 0)
            {
                uint multiplier = 1;
                uint* p = (currentChar in units);
                if (p !is null)
                {
                    consumeChar();
                    if (currentChar == 'i')
                    {
                        consumeChar();
                        multiplier = pow(1024, *p);
                    }
                    else
                    {
                        multiplier = pow(1000, *p);
                    }
                }

                debug {
                    stderr.writeln(
                        "new IntegerAtom: <", s, "> * ", multiplier
                    );
                }
                return new IntegerAtom(s.to!int * multiplier);
            }
            else if (dotCounter == 1)
            {
                debug {stderr.writeln("new FloatAtom: ", s);}
                return new FloatAtom(s.to!float);
            }
            else
            {
                throw new Exception(
                    "Invalid atom format: "
                    ~ s
                );
            }
        }
        else if (isSubst)
        {
            debug {stderr.writeln("new SubstAtom: ", s);}
            return new SubstAtom(s);
        }

        // Handle hexadecimal format, like 0xabcdef
        if (s.length > 2 && s[0..2] == "0x")
        {
            // XXX: should we handle FormatException, here?
            auto result = toLong(s);
            debug {stderr.writeln("new IntegerAtom: ", result);}
            return new IntegerAtom(result);
        }

        // Names that are boolean:
        switch (s)
        {
            case "true":
            case "yes":
                debug {stderr.writeln("new BooleanAtom(true)");}
                return new BooleanAtom(true);
            case "false":
            case "no":
                debug {stderr.writeln("new BooleanAtom(false)");}
                return new BooleanAtom(false);
            default:
                debug {stderr.writeln("new NameAtom: ", s);}
                return new NameAtom(s);
        }

    }
}
