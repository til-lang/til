module til.grammar;

import std.algorithm : among, canFind;
import std.conv : to;
import std.math : pow;
import std.range : back, popBack;

import til.conv;
import til.exceptions;
import til.nodes;


debug
{
    import std.array : join;
    import std.stdio;
}


const EOL = '\n';
const SPACE = ' ';
const TAB = '\t';
const PIPE = '|';

const OPERATORS = [
    '+', '-', '*', '/',
    '!', '=',
    '&', '|',
    '<', '>',
    '@', '^', '~'
];

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
    void push(string s)
    {
        stack ~= s ~ ":" ~ to!string(line);
        debug {stderr.writeln("NODES:", to!string(stack.join(" ")), " ← ");}
    }
    void pop()
    {
        auto popped = stack.back;
        stack.popBack;
        debug {stderr.writeln("NODES:", to!string(stack.join(" ")), " → ", popped);}
    }

    // --------------------------------------------
    SubProgram run()
    {
        push("program");
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
        pop();
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
        push("subprogram");
        Pipeline[] pipelines;

        consumeWhitespaces();

        while(!isStopper)
        {
            pipelines ~= consumePipeline();
        }

        pop();
        return new SubProgram(pipelines);
    }

    Pipeline consumePipeline()
    {
        push("pipeline");
        Command[] commands;

        consumeWhitespaces();

        while (!isEndOfLine && !isStopper)
        {
            auto command = consumeCommand();
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
        pop();
        return new Pipeline(commands);
    }

    Command consumeCommand()
    {
        push("command");
        NameAtom commandName = cast(NameAtom)consumeAtom();
        ListItem[] arguments;

        // That is: if the command HAS any argument:
        while (currentChar == SPACE)
        {
            consumeSpace();
            if (currentChar.among('}', ']', ')', '>', PIPE))
            {
                break;
            }

            arguments ~= consumeListItem();

            if (currentChar == EOL)
            {
                /*
                Verify if it is not a continuation:
                cmd a b c
                  . d e
                */
                consumeWhitespaces();
                if (currentChar == '.')
                {
                    consumeChar();
                    continue;
                }
                else
                {
                    break;
                }
            }
        }
        pop();
        return new Command(commandName.toString(), arguments);
    }

    ListItem consumeListItem()
    {
        debug {
            stderr.writeln("   consumeListItem");
            stderr.writeln("    - currentChar: '", currentChar, "'");
        }
        switch(currentChar)
        {
            case '{':
                return consumeSubList();
            case '[':
                return consumeExecList();
            case '(':
                return consumeSimpleList();
            case '<':
                return consumeExtraction();
            case '"':
                return consumeString();
            default:
                return consumeAtom();
        }
    }

    SubList consumeSubList()
    {
        push("SubList");
        auto open = consumeChar();
        assert(open == '{');
        auto subprogram = consumeSubProgram();
        auto close = consumeChar();
        assert(close == '}');

        pop();
        return new SubList(subprogram);
    }

    ExecList consumeExecList()
    {
        push("ExecList");
        auto open = consumeChar();
        assert(open == '[');
        auto subprogram = consumeSubProgram();
        auto close = consumeChar();
        assert(close == ']');

        pop();
        return new ExecList(subprogram);
    }

    SimpleList consumeSimpleList()
    {
        push("SimpleList");
        ListItem[] items;
        auto open = consumeChar();
        assert(open == '(');

        if (currentChar != ')')
        {
            items ~= consumeListItem();
        }
        while (currentChar != ')')
        {
            consumeSpace();
            items ~= consumeListItem();
        }

        auto close = consumeChar();
        assert(close == ')');

        pop();
        return new SimpleList(items);
    }

    ListItem consumeExtraction()
    {
        push("Extraction");
        ListItem[] items;
        auto open = consumeChar();
        assert(open == '<');

        // if (x < 10)
        // The above statement can be confounded
        // with the start of an Extraction.
        if (currentChar == SPACE)
        {
            return new OperatorAtom("<");
        }

        do
        {
            items ~= consumeListItem();
            consumeWhitespaces();
        }
        while (currentChar != '>');

        auto close = consumeChar();
        assert(close == '>');

        pop();
        return new Extraction(items);
    }

    String consumeString()
    {
        push("string");
        auto open = consumeChar();
        assert(open == '"');

        char[] token;
        StringPart[] parts;
        bool hasSubstitution = false;

        ulong index = 0;
        do 
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
                        break;
                    case 'n':
                        token ~= '\n';
                        break;
                    case 'r':
                        token ~= '\r';
                        break;
                    case 't':
                        token ~= '\t';
                        break;
                    // TODO: \u1234
                    default:
                        token ~= consumeChar();
                }
            }
            else if (currentChar != '"')
            {
                token ~= consumeChar();
            }
        }
        while (currentChar != '"');

        // Adds the eventual last part (in
        // simple strings it will be
        // the first part, always:
        if (token.length)
        {
            parts ~= new StringPart(token, false);
        }

        auto close = consumeChar();
        assert(close == '"');

        pop();
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

    Atom consumeAtom()
    {
        push("atom");
        char[] token;

        bool isNumber = true;
        bool mustBeNumber = false;
        bool isSubst = false;
        bool isOperator = false;
        uint dotCounter = 0;

        // `$x`
        if (currentChar == '$')
        {
            isNumber = false;
            isSubst = true;
            // Do NOT add `$` to the SubstAtom.
            consumeChar();
        }
        else
        {
            // `>=`
            while (!eof && OPERATORS.canFind(currentChar))
            {
                token ~= consumeChar();
            }

            if (token.length)
            {
                auto s = to!string(token);
                // `+`
                if (s != "-")
                {
                    if (!eof && !isWhitespace)
                    {
                        // *name = invalid!
                        throw new Exception(
                            "Invalid atom format: "
                            ~ s
                        );
                    }
                    return new OperatorAtom(s);
                }
                // `- `, like in `($a - $b)`
                else if (eof || isWhitespace)
                {
                    return new OperatorAtom(s);
                }
                // `-10`
                else
                {
                    mustBeNumber = true;
                }
            }
        }

        // The rest:
        while (!eof)
        {
            if (currentChar >= 'a' && currentChar <= 'z' || currentChar == '_')
            {
                if (mustBeNumber)
                {
                    auto s = to!string(token);
                    throw new Exception(
                        "Invalid atom format: "
                        ~ s
                    );
                }
                isNumber = false;
                isOperator = false;
            }
            else if (currentChar >= '0' && currentChar <= '9')
            {
            }
            else if (currentChar == '.')
            {
                dotCounter++;
            }
            else
            {
                break;
            }
            token ~= consumeChar();
        }

        debug {stderr.writeln(" token: ", token);}
        pop();

        string s = cast(string)token;
        debug {stderr.writeln(" s: ", s);}

        if (isNumber)
        {
            if (dotCounter == 0)
            {
                // `-`
                if (isOperator && s.length == 1)
                {
                    debug {stderr.writeln("new OperatorAtom: ", s);}
                    return new OperatorAtom(s);
                }
                else
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
        else if (isOperator)
        {
            debug {stderr.writeln("new OperatorAtom: ", s);}
            return new OperatorAtom(s);
        }

        // Handle hexadecimal format, like 0xabcdef
        if (s.length > 2 && s[0..2] == "0x")
        {
            auto result = toLong(s);
            if (result.success)
            {
                debug {stderr.writeln("new IntegerAtom: ", result.value);}
                return new IntegerAtom(result.value);
            }
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
