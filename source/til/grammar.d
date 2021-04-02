module til.grammar;

import std.array;
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
    ListItem[] items;
    ListItem[] firstArguments;
    int currentCounter = 0;

    foreach(child; p.children)
    {
        if (child.isPipe) {
            firstArguments = items;
            items = new ListItem[0];
            currentCounter = 0;
            continue;
        }

        switch(child.name)
        {
            case "Til.ListItem":
                auto li = analyseListItem(child);
                if (li !is null)
                {
                    items ~= li;
                }
                break;
            case "Til.List":
                auto l = analyseList(child);
                if (l !is null)
                {
                    items ~= l;
                }
                break;
            default:
                writeln("Til.List: " ~ child.name);
        }

        // Right after the first item in the list we
        // insert the "firstArguments" list:
        if (currentCounter == 0 && firstArguments !is null)
        {
            items ~= new List(firstArguments);
            firstArguments = null;
        }

        currentCounter++;
    }
    return new List(items);
}

bool isPipe(ParseTree p)
{
    return p.children[0].name == "Til.Pipe";
}

ListItem analyseListItem(ParseTree p)
{
    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.Comment":
                continue;
            case "Til.ExecList":
                return analyseList(child);
            case "Til.SubList":
                auto sl = analyseList(child);
                sl.execute = false;
                return sl;
            case "Til.String":
                return analyseString(child);
            case "Til.Atom":
                return analyseAtom(child);
            default:
                throw new InvalidException(
                    "ListItem seems invalid: "
                    ~ child.name ~ " : "
                    ~ to!string(child.matches)
                );
        }
    }
    // Now we **can** reach this point, for a Comment
    // also forms a proper list...
    return null;
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
    }
    return new String(parts, substitutions);
}

Atom analyseAtom(ParseTree p)
{
    string str = p.matches.join("");
    auto atom = new Atom(str);

    foreach(child; p.children)
    {
        final switch(child.name)
        {
            case "Til.CommonAtom":
                break;
            case "Til.Name":
                atom.namePath = extractAtomNamePath(child);
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

string[] extractAtomNamePath(ParseTree p)
{
    string[] thePath;

    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.NamePart":
                thePath ~= child.matches[0];
                break;
            default:
                throw new Exception(
                    "Invalid child for Til.Name: "
                    ~ child.name
                );
        }
    }
    return thePath;
}
