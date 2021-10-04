module til.grammar;

import std.algorithm : among;
import std.conv : to;
import std.math : pow;
import std.range : back, popBack;

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
const BACKGROUND = '&';


// Integers units:
uint[char] units;

static this()
{
    units['K'] = 1;
    units['M'] = 2;
    units['G'] = 3;
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
        debug {stderr.writeln("STACK:", to!string(stack.join(" ")), " ← ");}
    }
    void pop()
    {
        auto popped = stack.back;
        stack.popBack;
        debug {stderr.writeln("STACK:", to!string(stack.join(" ")), " → ", popped);}
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
    char consumeChar()
    {
        if (eof)
        {
            throw new Exception("Code input already ended.");
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
        auto result =  code[index++];
        col++;

        if (result == EOL)
        {
            col = 0;
            line++;
            debug {stderr.writeln("line ", line);}
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

        debug {stderr.writeln("whitespaces start");}
        bool consumed = true;

        while (consumed && !eof)
        {
            consumed = false;
            // Common whitespaces:
            while (isWhitespace && !eof)
            {
                consumeChar();
                consumed = true;
            }
            // Comments:
            if (currentChar == '#')
            {
                consumeLine();
                consumed = true;
            }
        }
        debug {stderr.writeln("            end");}
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
        debug {stderr.writeln("consuming whitespace");}
        assert(isWhitespace);
        consumeChar();
    }
    void consumeSpace()
    {
        debug {stderr.writeln("consuming whitespace");}
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
            commands ~= consumeCommand();

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
        bool inBackground = false;

        // That is: if the command HAS any argument:
        while (currentChar == SPACE)
        {
            consumeSpace();
            debug {stderr.writeln("after space: ", currentChar);}
            if (currentChar.among('}', ']', ')', '>', PIPE))
            {
                break;
            }
            else if (currentChar == BACKGROUND)
            {
                inBackground = true;
                debug {stderr.writeln("IN BACKGROUND!");}
                consumeChar();
                continue;
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
        return new Command(commandName.toString(), arguments, inBackground);
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
        string[] parts;
        bool hasSubstitutions = false;

        do 
        {
            if (currentChar == '$')
            {
                hasSubstitutions = true;
                if (token.length)
                {
                    parts ~= cast(string)token;
                    token = new char[0];
                }

                // Current part:

                // Add the '$' in front of current part:
                token ~= consumeChar();

                bool enclosed = (currentChar == '{');
                if (enclosed) consumeChar();

                while ((currentChar >= 'a' && currentChar <= 'z')
                        || (currentChar >= '0' && currentChar <= '9')
                        || currentChar == '.' || currentChar == '_')
                {
                    token ~= consumeChar();
                }

                if (token.length > 1)
                {
                    if (enclosed)
                    {
                        assert(currentChar == '}');
                        consumeChar();
                    }
                    parts ~= cast(string)token;
                }
                else
                {
                    throw new Exception(
                        "Invalid string: "
                        ~ to!string(parts)
                        ~ cast(string)token
                    );
                }
                token = new char[0];
            }
            else
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
            parts ~= cast(string)token;
        }

        auto close = consumeChar();
        assert(close == '"');

        pop();
        if (hasSubstitutions)
        {
            debug {stderr.writeln("new SubstString: ", parts);}
            return new SubstString(parts);
        }
        else
        {
            debug {stderr.writeln("new String: ", parts);}
            return new String(parts[0]);
        }
    }

    Atom consumeAtom()
    {
        push("atom");
        char[] token;
        size_t counter = 0;

        bool isNumber = true;
        bool isSubst = false;
        bool isInput = false;
        bool isOperator = false;
        uint dotCounter = 0;

        // Characters allowed only in the beginning:
        switch (currentChar)
        {
            case '-':
                isOperator = true;
                token ~= consumeChar();
                break;

            case '>':
                isInput = true;
                isNumber = false;
                goto case;
            case '<':
            case '+':
            case '*':
            case '/':
            case '|':
            case '&':
            case '=':
                isOperator = true;
                isNumber = false;
                token ~= consumeChar();
                break;

            case '$':
                isNumber = false;
                isSubst = true;
                // Throw the character away:
                consumeChar();
                break;

            default:
                break;
        }

        // Operators may have two characters:
        if (isOperator)
        {
            switch (currentChar)
            {
                case '=':
                case '>':
                case '<':
                case '*':
                case '/':
                case '|':
                case '&':
                    // TODO: check if the pair is actually valid
                    // (invalid example: "&|")
                    token ~= consumeChar();
                    break;
                default:
                    break;
            }
        }

        // And all the others:
        while (true)
        {
            if (currentChar >= 'a' && currentChar <= 'z' || currentChar == '_')
            {
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

        pop();

        string s = cast(string)token;

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
        else if (isInput && !isOperator)
        {
            debug {stderr.writeln("new InputNameAtom: ", s);}
            return new InputNameAtom(s[1..$]);
        }
        else if (isOperator)
        {
            debug {stderr.writeln("new OperatorAtom: ", s);}
            return new OperatorAtom(s);
        }
        
        debug {stderr.writeln("new NameAtom: ", s);}
        return new NameAtom(cast(string)token);
    }
}
