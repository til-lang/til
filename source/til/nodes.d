module til.nodes;

import std.conv : to;
import std.stdio : writeln;
import std.algorithm.iteration : map, joiner;

import til.escopo;
import til.exceptions;
import til.grammar;


alias Value = string;

enum ScopeExitCodes
{
    Continue,
    Success,
    Failure,
}

class List
{
    ListItem[] items;
    ScopeExitCodes scopeExit = ScopeExitCodes.Continue;
    bool hasPipe = true;

    this()
    {
    }
    this(ListItem item)
    {
        this.items ~= item;
    }
    this(ListItem[] items)
    {
        this.items = items;
    }
    this(List sl, bool execute)
    {
        this.items ~= new ListItem(sl, execute);
    }

    override string toString()
    {
        auto list = items
            .map!(x => to!string(x))
            .joiner(" ");
        return to!string(list);
    }
    ListItem opIndex(int i)
    {
        return items[i];
    }
    ListItem[] opSlice(ulong start, ulong end)
    {
        return items[start..end];
    }
    ulong length()
    {
        return items.length;
    }
    @property ulong opDollar()
    {
        return this.length;
    }

    ListItem[] organize()
    {
        if (!this.hasPipe)
        {
            writeln(" - List ", this, " has no pipes.");
            return this.items;
        }

        ListItem[] currentItems;
        ListItem[] newArguments;

        /*
           Organize a piped list:

        1.   1 2 3  > filter {x != 2} < std.out
            {1 2 3} >...
        2.   filter {1 2 3} {x != 2}  < std.out
            {filter {1 2 3} {x != 2}} < std.out
        3.   std.out [filter {1 2 3} {x != 2}
        */

        int subIndex = 0;
        foreach(idx, item; items)
        {
            switch(item.type)
            {
                case ListItemType.ForwardPipe:
                    // Generate a SubItem that is executable:
                    auto program = new List(currentItems);
                    writeln(" - turned into executable: ", program);
                    auto executableItem = new ListItem(program, true);

                    // Reset newArguments:
                    newArguments = new ListItem[1];
                    newArguments[0] = executableItem;

                    // Reset currentItems:
                    currentItems = new ListItem[0];

                    subIndex = 0;

                    break;

                default:
                    currentItems ~= item;
                    subIndex++;
                    if (subIndex == 1 && newArguments.length > 0)
                    {
                        currentItems ~= newArguments;
                        newArguments = new ListItem[0];
                    }
            }
        }
        return currentItems;
    }

    ListItem[] evaluate(Escopo escopo)
    {
        return this.evaluate(this.items, escopo);
    }
    static ListItem[] evaluate(ListItem[] items, Escopo escopo)
    {
        ListItem[] newItems;

        foreach(index, item; items)
        {
            switch(item.type)
            {
                case ListItemType.Atom:
                case ListItemType.String:
                    newItems ~= new ListItem(item.evaluate(escopo), false);
                    break;
                // [subprograms resolution]
                case ListItemType.SubList:
                    // If the subprogram should be executed,
                    // then execute and replace itself with
                    // another subprogram that needs no
                    // further execution:
                    if (item.execute)
                    {
                        writeln("Running subprogram: " ~ to!string(item));
                        List result = item.run(escopo);
                        newItems ~= new ListItem(result, false);
                    }
                    else
                    {
                        newItems ~= item;
                    }
                    break;
                default:
                    newItems ~= item;
                    break;
            }
        }
        return newItems;
    }

    List run(Escopo escopo)
    {
        auto organized = this.organize;
        auto evaluatedItems = evaluate(organized, escopo);
        if (this.hasPipe)
        {
            writeln(" -- original:", this.items);
            writeln(" -- organized:", organized);
            writeln(" -- evaluated:", evaluatedItems);
        }

        writeln("List.run:" ~ to!string(evaluatedItems));
        ListItem command = this.items[0];
        auto arguments = new List(evaluatedItems[1..$]);

        // lists.order 3 4 1 2 > std.out
        if (command.type == ListItemType.Atom)
        {
            // This is a command-like List:
            auto cmd = to!string(command.evaluate(escopo));
            return escopo.run_command(cmd, arguments);
        }

        writeln(" - command.type: ", command.type);

        // ------------------------------------------
        // This list is not an expression, but a list
        // of other lists (a program, that is):
        List returned;

        foreach(item; evaluatedItems)
        {
            writeln("run-list> " ~ to!string(item));
            returned = item.run(escopo);
            if (returned !is null && returned.scopeExit != ScopeExitCodes.Continue)
            {
                break;
            }
        }

        // Returns whatever was the result of the last Expression,
        writeln(" - returned: " ~ to!string(returned));
        return returned;
    }

    Value toString(Escopo escopo)
    {
        return to!string(this.items
            .map!(x => to!string(x.evaluate(escopo)))
            .joiner(" "));
    }

    // Extract a list of strings/Values:
    Value[] values(Escopo escopo)
    {
        Value[] theValues;
        foreach(item; items)
        {
            theValues ~= item.values(escopo);
        }
        return theValues;
    }
}

enum ListItemType
{
    Undefined,
    Atom,
    String,
    SubList,
    ForwardPipe,
}

class ListItem
{
    Atom atom;
    String str;
    List sublist;

    bool execute;

    ListItemType type;

    this(ListItemType type)
    {
        this.type = type;
    }
    this(Atom a)
    {
        this.atom = a;
        this.type = ListItemType.Atom;
    }
    this(String s)
    {
        this.str = s;
        this.type = ListItemType.String;
    }
    this(List sl, bool execute)
    {
        this.sublist = sl;
        this.type = ListItemType.SubList;
        this.execute = execute;
    }

    // Operators:
    override string toString()
    {
        final switch(this.type)
        {
            case ListItemType.ForwardPipe:
                return " |> ";
            case ListItemType.Atom:
                return to!string(this.atom);
            case ListItemType.String:
                return to!string(this.str);
            case ListItemType.SubList:
                return to!string(this.sublist);
            case ListItemType.Undefined:
                return "UNDEFINED!";
        }
    }

    // Extract a list of strings/Values:
    Value[] values(Escopo escopo)
    {
        final switch(this.type)
        {
            case ListItemType.ForwardPipe:
                throw new Exception("Trying to get value from pipe");

            case ListItemType.Atom:
                Value[] v;
                v ~= to!string(this.atom.evaluate(escopo));
                return v;
            case ListItemType.String:
                Value[] v;
                v ~= to!string(this.str.evaluate(escopo));
                return v;
            case ListItemType.SubList:
                if (this.execute) {
                    throw new Exception("Not implemented (SubList)");
                }
                return this.sublist.values(escopo);

            case ListItemType.Undefined:
                throw new Exception("Not implemented (Undefined)");
        }
        assert(0);
    }

    List run(Escopo escopo)
    {
        if (this.type != ListItemType.SubList)
        {
            throw new Exception(
                "ListItem: Cannot run a " ~ to!string(this.type)
            );
        }
        return this.sublist.run(escopo);
    }

    List evaluate(Escopo escopo)
    {
        switch(this.type)
        {
            case ListItemType.Atom:
                return this.atom.evaluate(escopo);
            case ListItemType.String:
                return this.str.evaluate(escopo);
            case ListItemType.SubList:
                auto newItems = this.sublist.evaluate(escopo);
                return new List(newItems);
            default:
                throw new Exception("wut?");
        }
        assert(0);
    }
}

class String
{
    string repr;
    string[] parts;
    string[int] substitutions;

    this(string repr)
    {
        this.repr = repr;
    }
    this(string[] parts, string[int] substitutions)
    {
        this.parts = parts;
        this.substitutions = substitutions;
    }

    List evaluate(Escopo escopo)
    {
        if (this.substitutions.length == 0)
        {
            auto li = new ListItem(this);
            return new List(li);
        }

        string result;
        string subst;
        Value value;

        foreach(index, part;parts)
        {
            subst = this.substitutions.get(cast(int)index, null);
            if (subst is null)
            {
                value = part;
            }
            else
            {
                List l = escopo[subst];
                if (l is null)
                {
                    value = "";
                }
                else {
                    value = to!string(l);
                }
            }
            result ~= value;
        }

        writeln("resolving " ~ to!string(this) ~ " = " ~ result);
        auto li = new ListItem(new String(result));
        return new List(li);
    }
    override string toString()
    {
        // TODO: check if we ARE setting repr somewhere.
        if (this.repr !is null)
        {
            return "s\"" ~ this.repr ~ "\"";
        }
        // Or else:
        return "S\"" ~ to!string(this.parts
            .map!(x => to!string(x))
            .joiner("")) ~ "\"";
    }
}

class Atom
{
    string repr;

    this(string s)
    {
        this.repr = s;
    }
    this(List l)
    {
        this.repr = to!string(l);
    }

    List evaluate(Escopo escopo)
    {
        if (this.repr[0..1] == "$")
        {
            return escopo[this.repr[1..$]];
        }
        else {
            auto li = new ListItem(this);
            return new List(li);
        }
    }

    override string toString()
    {
        return this.repr;
    }
}
