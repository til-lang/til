module til.grammar;

import std.algorithm : among, canFind;
import std.conv : to;
import std.math : pow;

import til.conv;
import til.exceptions;
import til.nodes;


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
    SubProgram run()
    {
        SubProgram sp;
        try
        {
            sp = consumeSubProgram();
        }
        catch(Exception ex)
        {
            throw new Exception(
                "Error at line " ~
                to!string(line) ~
                ", column " ~
                to!string(col) ~
                ": " ~ to!string(ex)
            );
        }
        return sp;
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
                stderr.writeln("whitespaces (" ~ to!string(counter) ~ ")");
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
    SubProgram consumeSubProgram()
    {
        Pipeline[] pipelines;

        consumeWhitespaces();

        while(!isStopper)
        {
            pipelines ~= consumePipeline();
        }

        return new SubProgram(pipelines);
    }

    Pipeline consumePipeline()
    {
        CommandCall[] commands;

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
        // inline transform/foreach:
        if (currentChar == '{')
        {
            CommandCall nextCall = foreachInline();
            if (!isEndOfLine)
            {
                // Whops! It's not a foreach.inline, but a transform.inline!
                nextCall.name = "transform.inline";
                consumeWhitespaces();
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
            stderr.writeln("   consumeItem");
            stderr.writeln("    - currentChar: '", currentChar, "'");
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
                return consumeExtraction();
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

                        return new String(to!string(token[0..end+1]));
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

    // Not used since consumeSubString:
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
            consumeSpace();
            items ~= consumeItem();
        }

        auto close = consumeChar();
        assert(close == ')');

        return new SimpleList(items);
    }

    Item consumeExtraction()
    {
        Item[] items;
        auto open = consumeChar();
        assert(open == '<');

        // if (x < 10)
        // The above statement can be confounded
        // with the start of an Extraction.
        if (currentChar == SPACE)
        {
            return new String("<");
        }

        do
        {
            items ~= consumeItem();
            consumeWhitespaces();
        }
        while (currentChar != '>');

        auto close = consumeChar();
        assert(close == '>');

        return new Extraction(items);
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
                        ~ "parts:" ~  to!string(parts)
                        ~ "; token:" ~ cast(string)token
                        ~ "; length:" ~ to!string(token.length)
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
            else if (currentChar == '(')
            {
                // $(1 + 2 + 4)
                SimpleList list = consumeSimpleList();
                return list.infixProgram();
            }
            else if (currentChar >= 'A' && currentChar <= 'Z')
            {
                uint* p = (currentChar in units);
                if (p is null)
                {
                    throw new Exception(
                        "Invalid character in name: "
                        ~ cast(string)token
                        ~ to!string(currentChar)
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

        if (isNumber)
        {
            if (s == "-")
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
                return new IntegerAtom(to!long(s) * multiplier);
            }
            else if (dotCounter == 1)
            {
                debug {stderr.writeln("new FloatAtom: ", s);}
                return new FloatAtom(to!float(s));
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
