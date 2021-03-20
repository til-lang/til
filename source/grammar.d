module til.grammar;

import std.stdio;
import std.conv;

import pegged.grammar;

import til.nodes;


void execute(ParseTree p)
{
    switch(p.name)
    {
        case "Til":
            auto sub = executeTil(p);
            sub.run();
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
    assert(0);
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
        }
    }
    assert(0);
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
            default:
                writeln("Til.Expression: " ~ child.name);
        }
    }
    assert(0);
}

ForwardExpression executeForwardExpression(ParseTree p)
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
            case "Til.ForwardPipe":
                // TODO: use it to validate the expression!
                writeln("> ForwardPipe");
                break;
            default:
                writeln("Til.ForwardExpression: " ~ child.name);
        }
    }
    auto fe = new ForwardExpression(expressions);
    return fe;
}

ExpansionExpression executeExpansionExpression(ParseTree p)
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
            case "Til.ExpansionPipe":
                // TODO: use it to validate the expression!
                writeln("> ExpansionPipe");
                break;
            default:
                writeln("Til.ExpansionExpression: " ~ child.name);
        }
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
    assert(0);
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

Atom executeAtom(ParseTree p)
{
    writeln("> Atom: " ~ p.matches[0]);
    return new Atom(p.matches[0]);
}
