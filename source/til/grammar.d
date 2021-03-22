module til.grammar;

import std.conv : to;
import std.stdio : writeln;

import pegged.grammar;

import til.escopo;
import til.exceptions;
import til.nodes;
import til.til;


List execute(ParseTree p)
{
    auto escopo = new Escopo();
    return execute(escopo, p);
}

List execute(Escopo escopo, ParseTree p)
{
    switch(p.name)
    {
        case "Til":
            auto program = executeTil(escopo, p);
            return program.run();
        default:
            writeln("execute: Not recognized: " ~ p.name);
    }
    assert(0);
}

Program executeTil(Escopo escopo, ParseTree p)
{
    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.Program":
                auto program = executeProgram(escopo, child);
                return program;
            default:
                writeln("executeTil: Not recognized: " ~ child.name);
        }
    }
    throw new InvalidException("Program seems invalid");
}

Program executeProgram(Escopo escopo, ParseTree p)
{
    Expression[] expressions;

    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.Expression":
                auto e = executeExpression(child);
                expressions ~= e;
                break;
            default:
                writeln("Til.Program.child: " ~ child.name);
                writeln(child);
                throw new InvalidException("Program seems invalid");
        }
    }
    return new Program(escopo, expressions);
}

Expression executeExpression(ParseTree p)
{
    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.ForwardExpression":
                auto fe = executeForwardExpression(child);
                return new Expression(fe);
            case "Til.ExpansionExpression":
                auto ee = executeExpansionExpression(child);
                return new Expression(ee);
            case "Til.List":
                auto l = executeList(child);
                return new Expression(l);
            default:
                writeln("Til.Expression: " ~ child.name);
        }
    }
    throw new InvalidException("Expression seems invalid");
}

ForwardExpression executeForwardExpression(ParseTree p)
{
    Expression[] expressions;
    int pipeCounter = 0;

    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.Expression":
                auto e = executeExpression(child);
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

ExpansionExpression executeExpansionExpression(ParseTree p)
{
    Expression[] expressions;
    int pipeCounter = 0;

    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.Expression":
                auto e = executeExpression(child);
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

List executeList(ParseTree p)
{
    ListItem[] listItems;

    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.ListItem":
                auto li = executeListItem(child);
                listItems ~= li;
                break;
            default:
                writeln("Til.List: " ~ child.name);
        }
    }
    return new List(listItems);
}

ListItem executeListItem(ParseTree p)
{
    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.SubProgram":
                auto sp = executeSubProgram(child);
                return new ListItem(sp, ListItemType.SubProgram);
            case "Til.String":
                auto s = executeString(child);
                return new ListItem(s, ListItemType.String);
            case "Til.Name":
                auto n = executeName(child);
                return new ListItem(n, ListItemType.Name);
            case "Til.Atom":
                auto a = executeAtom(child);
                return new ListItem(a, ListItemType.Atom);
            default:
                writeln("Til.ListItem: " ~ child.name);
                throw new InvalidException("ListItem seems invalid: " ~ to!string(child.matches));
        }
    }
    assert(0);
}

// Strings:

string executeSubProgram(ParseTree p)
{
    writeln("> SubProgram: " ~ p.matches[0]);
    return p.matches[0];
}

string executeString(ParseTree p)
{
    writeln("> String: " ~ p.matches[0]);
    return p.matches[0];
}

string executeName(ParseTree p)
{
    writeln("> Name: " ~ p.matches[0]);
    return p.matches[0];
}

string executeAtom(ParseTree p)
{
    writeln("> Atom: " ~ p.matches[0]);
    return p.matches[0];
}
