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
    bool hasPipe = false;

    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.ListItem":
                auto li = analyseListItem(child);
                if (li !is null)
                {
                    listItems ~= li;
                    if (li.type == ListItemType.ForwardPipe)
                    {
                        hasPipe = true;
                    }
                }
                break;
            case "Til.List":
                auto l = analyseList(child);
                if (l !is null)
                {
                    auto li = new ListItem(l, false);
                    listItems ~= li;
                }
                break;
            default:
                writeln("Til.List: " ~ child.name);
        }
    }
    if (listItems.length == 0) return null;
    auto list = new List(listItems);
    list.hasPipe = hasPipe;
    return list;
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
    // Now we **can** reach this point, for a Comment
    // also forms a proper list...
    return null;
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
    string str = p.matches[0];
    auto atom = new Atom(str);

    foreach(child; p.children)
    {
        final switch(child.name)
        {
            case "Til.CommonAtom":
                break;
            case "Til.Float":
                atom.floatingPoint = to!float(str);
                break;
            case "Til.Integer":
                atom.integer = to!int(str);
                break;
            case "Til.Boolean":
                atom.boolean = (
                    child.children[0].name == "Til.BooleanTrue"
                );
                break;
        }
    }
    return atom;
}
