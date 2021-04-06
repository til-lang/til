module til.grammar;

import std.array;
import std.conv : to;
import std.experimental.logger;

import pegged.grammar;

import til.exceptions;
import til.nodes;
import til.til;


ExecList analyse(ParseTree p)
{
    switch(p.name)
    {
        case "Til":
            return analyseTil(p);
        default:
            trace("analyse: Not recognized: " ~ p.name);
    }
    assert(0);
}

ExecList analyseTil(ParseTree p)
{
    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.Program":
                auto program = analyseProgram(child);
                return program;
            default:
                trace("analyseTil: Not recognized: " ~ child.name);
        }
    }
    throw new InvalidException("Program seems invalid");
}

ExecList analyseProgram(ParseTree p)
{
    ListItem[] items;

    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.List":
                auto li = analyseListItems(child);
                if (li !is null)
                {
                    items ~= new CommonList(li);
                }
                break;
            default:
                trace("Til.List: " ~ child.name);
                throw new InvalidException("Program seems invalid");
        }
    }
    return new ExecList(items);
}

ListItem[] analyseListItems(ParseTree p)
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
                auto li = analyseListItems(child);
                if (li !is null)
                {
                    items ~= new CommonList(li);
                }
                break;
            default:
                trace("Til.List: " ~ child.name);
        }

        // Right after the first item in the list we
        // insert the "firstArguments" list:
        if (currentCounter == 0 && firstArguments !is null)
        {
            // Important: an ExecList should always
            // contain 1 > N CommonLists!
            auto cl = new CommonList(firstArguments);
            items ~= new ExecList(cl);
            firstArguments = null;
        }

        currentCounter++;
    }
    return items;
}

ListItem[] analyseSimpleListItems(ParseTree p)
{
    ListItem[] items;

    foreach(child; p.children)
    {
        switch(child.name)
        {
            case "Til.List":
                auto li = analyseListItems(child);
                if (li !is null)
                {
                    return li;
                }
                break;
            default:
                throw new InvalidException(
                    "Invalid Item inside SimpleList"
                );
        }
    }
    return items;
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
                return new ExecList(analyseListItems(child));
            case "Til.SubList":
                return new SubList(analyseListItems(child));
            case "Til.SimpleList":
                return new SimpleList(analyseSimpleListItems(child));
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
                atom.type = ObjectTypes.Name;
                break;
            case "Til.Float":
                atom.floatingPoint = to!float(str);
                atom.type = ObjectTypes.Float;
                break;
            case "Til.Integer":
                atom.integer = to!int(str);
                atom.type = ObjectTypes.Integer;
                break;
            case "Til.Boolean":
                atom.boolean = (
                    child.children[0].name == "Til.BooleanTrue"
                );
                atom.type = ObjectTypes.Boolean;
                break;
            case "Til.Operator":
                atom.type = ObjectTypes.Operator;
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
            case "Til.QuestionMark":
                // Appends the "?" in the end of the last part:
                thePath[$-1] ~= child.matches[0];
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
