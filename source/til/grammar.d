module til.grammar;

import std.conv : to;
import std.stdio : writeln;

import pegged.grammar;

import til.exceptions;
import til.nodes;
import til.til;


List analyse(ParseTree p)
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

List analyseTil(ParseTree p)
{
    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.Program":
                auto program = analyseList(child);
                return program;
            default:
                writeln("analyseTil: Not recognized: " ~ child.name);
        }
    }
    throw new InvalidException("Program seems invalid");
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
            case "Til.List":
                auto l = analyseList(child);
                auto li = new ListItem(l, false);
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
            case "Til.Comment":
                continue;
            case "Til.Pipe":
                return analysePipe(child);
            case "Til.ExecList":
                auto sl = analyseList(child);
                return new ListItem(sl, true);
            case "Til.SubList":
                auto sl = analyseList(child);
                return new ListItem(sl, false);
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

ListItem analysePipe(ParseTree p)
{
    foreach(index, child; p.children)
    {
        switch(child.name)
        {
            case "Til.ForwardPipe":
                return new ListItem(ListItemType.ForwardPipe);
            default:
                throw new InvalidException(
                    "ListItem/Pipe seems invalid: " ~ child.name
                );
        }
    }
    assert(0);
}

// Strings:
String analyseString(ParseTree p)
{
    string[] parts;
    string[int] substitutions;

    foreach(index, child; p.children)
    {
        final switch(child.name)
        {
            case "Til.Substitution":
                substitutions[cast(int)index] = child.matches[0][1..$];
                // fallthrough:
                goto case;
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
