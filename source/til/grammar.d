module til.grammar;

import std.conv : to;
import std.stdio : writeln;

import pegged.grammar;

import til.exceptions;
import til.nodes;
import til.escopo;


mixin(grammar(`
    Til:
        Program             <- blank* SubProgram endOfInput
        SubProgram          <- Expression* (eol blank* Expression)* blank*
        Expression          <- ForwardExpression / ExpansionExpression / List / String
        ForwardExpression   <- Expression ForwardPipe Expression
        ExpansionExpression <- Expression ExpansionPipe Expression
        ForwardPipe         <- " > "
        ExpansionPipe       <- " < "
        List                <- ListItem (' ' ListItem)*
        ListItem            <- "{" SubProgram "}" / DotList
        String              <~ doublequote (!doublequote .)* doublequote
        DotList             <- ColonList ('.' ColonList)*
        ColonList           <- Atom (':' Atom)*
        Atom                <~ [A-z0-9\-+_$]+
    `));


void execute(ParseTree p)
{
    auto masterScope = new Escopo(null);

    switch(p.name)
    {
        case "Til":
            auto sub = executeTil(p);
            sub.run(masterScope);
            break;
        default:
            writeln("execute: Not recognized: " ~ p.name);
    }
}

SubProgram executeTil(ParseTree p)
{
    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.Program":
                auto sub = executeProgram(child);
                return sub;
            default:
                writeln("executeTil: Not recognized: " ~ child.name);
        }
    }
    throw new InvalidException("Program seems invalid");
}

SubProgram executeProgram(ParseTree p)
{
    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.SubProgram":
                auto sub = executeSubProgram(child);
                writeln("> Program:\n" ~ to!string(sub));
                return sub;
            default:
                writeln("Til.Program.child: " ~ child.name);
                writeln(child);
        }
    }
    throw new InvalidException("Program seems invalid");
}

SubProgram executeSubProgram(ParseTree p)
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
                writeln("Til.SubProgram: " ~ p.name);
        }
    }
    return new SubProgram(expressions);
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
            case "Til.String":
                auto s = executeString(child);
                return new Expression(s);
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
            "ExpansionExpression has more than 1 pipe!"
        );
    }
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
                return new ListItem(sp);
            case "Til.DotList":
                auto dl = executeDotList(child);
                return new ListItem(dl);
            default:
                writeln("Til.ListItem: " ~ child.name);
        }
    }
    throw new InvalidException("List seems invalid");
}

DotList executeDotList(ParseTree p)
{
    ColonList[] colonLists;

    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.ColonList":
                auto c = executeColonList(child);
                colonLists ~= c;
                break;
            default:
                writeln("Til.DotList: " ~ child.name);
        }
    }
    return new DotList(colonLists);
}

ColonList executeColonList(ParseTree p)
{
    Atom [] atoms;
    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.Atom":
                auto a = executeAtom(child);
                atoms ~= a;
                break;
            default:
                writeln("Til.ColonList: " ~ child.name);
        }
    }
    return new ColonList(atoms);
}

string executeString(ParseTree p)
{
    writeln("> String: " ~ p.matches[0]);
    return p.matches[0];
}

Atom executeAtom(ParseTree p)
{
    writeln("> Atom: " ~ p.matches[0]);
    return new Atom(p.matches[0]);
}
