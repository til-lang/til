module til.grammar;

import std.conv : to;
import std.stdio : writeln;

import pegged.grammar;

import til.exceptions;
import til.nodes;
import til.til;


Program analyse(ParseTree p)
{
    switch(p.name)
    {
        case "Til":
            return analyseTil(p);
        default:
            writeln("analyse: Not recognized: " ~ p.name);
    }
    assert(0);
}

Program analyseTil(ParseTree p)
{
    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.Program":
                auto program = analyseProgram(child);
                return program;
            default:
                writeln("analyseTil: Not recognized: " ~ child.name);
        }
    }
    throw new InvalidException("Program seems invalid");
}

Program analyseProgram(ParseTree p)
{
    SubProgram subprogram;

    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.SubProgram":
                subprogram = analyseSubProgram(child);
                break;
            default:
                writeln("Til.Program.child: " ~ child.name);
                throw new InvalidException("Program seems invalid");
        }
    }
    return new Program(subprogram);
}

ParseTree extractSubProgram(ParseTree p)
{
    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.SubProgram":
                return child;
            default:
                throw new InvalidException("extractSubProgram: Program seems invalid: " ~ child.name);
        }
    }
    throw new InvalidException("extractSubProgram: Program seems invalid.");
}

SubProgram analyseSubProgram(ParseTree p)
{
    Expression[] expressions;
    // Pre-allocate some memory:
    expressions.reserve(p.children.length);

    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.Expression":
                auto e = analyseExpression(child);
                if (e is null) continue;
                expressions ~= e;
                break;
            default:
                writeln("Til.SubProgram.child: " ~ child.name);
                throw new InvalidException("Program seems invalid");
        }
    }
    return new SubProgram(expressions);
}

Expression analyseExpression(ParseTree p)
{
    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.ForwardExpression":
                auto fe = analyseForwardExpression(child);
                return new Expression(fe);
            case "Til.ExpansionExpression":
                auto ee = analyseExpansionExpression(child);
                return new Expression(ee);
            case "Til.List":
                auto l = analyseList(child);
                return new Expression(l);
            case "Til.Comment":
                writeln("Til.Expression: Comment: " ~ child.matches[0]);
                return null;
            default:
                writeln("Til.Expression: " ~ child.name);
        }
    }
    throw new InvalidException("Expression seems invalid");
}

ForwardExpression analyseForwardExpression(ParseTree p)
{
    Expression[] expressions;
    int pipeCounter = 0;

    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.Expression":
                auto e = analyseExpression(child);
                expressions ~= e;
                break;
            case "Til.ForwardPipe":
                writeln("> ForwardPipe");
                pipeCounter++;
                break;
            default:
                writeln("Til.ForwardExpression: " ~ child.name);
        }
    }
    if (pipeCounter != 1)
    {
        throw new InvalidException(
            "ForwardExpression has more than 1 pipe!"
        );
    }
    if (expressions.length < 2)
    {
        throw new InvalidException(
            "ForwardExpression has not enough Expressions!"
        );
    }
    writeln("ForwardExpression has ", expressions.length, " Expressions");
    auto fe = new ForwardExpression(expressions);
    return fe;
}

ExpansionExpression analyseExpansionExpression(ParseTree p)
{
    Expression[] expressions;
    int pipeCounter = 0;

    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.Expression":
                auto e = analyseExpression(child);
                expressions ~= e;
                break;
            case "Til.ExpansionPipe":
                writeln("> ExpansionPipe");
                pipeCounter++;
                break;
            default:
                writeln("Til.ExpansionExpression: " ~ child.name);
        }
    }
    if (pipeCounter != 1)
    {
        throw new InvalidException(
            "ExpansionExpression has more than 1 pipe!"
        );
    }
    return new ExpansionExpression(expressions);
}

List analyseList(ParseTree p)
{
    ListItem[] listItems;

    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.ListItem":
                auto li = analyseListItem(child);
                listItems ~= li;
                break;
            default:
                writeln("Til.List: " ~ child.name);
        }
    }
    return new List(listItems);
}

ListItem analyseListItem(ParseTree p)
{
    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.StringProgram":
                auto sp = extractSubProgram(child).analyseSubProgram;
                return new ListItem(sp, false);
            case "Til.SubProgramCall":
                auto sp = extractSubProgram(child).analyseSubProgram;
                return new ListItem(sp, true);
            case "Til.String":
                auto s = analyseString(child);
                return new ListItem(s);
            case "Til.Atom":
                auto a = analyseAtom(child);
                return new ListItem(a);
            default:
                writeln("Til.ListItem: " ~ child.name);
                throw new InvalidException("ListItem seems invalid: " ~ to!string(child.matches));
        }
    }
    assert(0);
}

// Strings:
String analyseString(ParseTree p)
{
    string[] parts;
    string[int] substitutions;

    int index = 0;
    foreach(child; p.children)
    {
        final switch(child.name)
        {
            case "Til.Substitution":
                substitutions[index++] = child.matches[0][1..$];
                // fallthrough:
            case "Til.NotSubstitution":
                parts ~= child.matches[0];
        }
        writeln(" " ~ child.name ~ ":", child.matches[0]);
    }
    return new String(parts, substitutions);
}

Atom analyseAtom(ParseTree p)
{
    writeln("> Atom: " ~ p.matches[0]);
    return new Atom(p.matches[0]);
}
