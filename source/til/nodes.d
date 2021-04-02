module til.nodes;

import std.conv : to;
import std.stdio : writeln;
import std.algorithm.iteration : map, joiner;

import til.escopo;
import til.exceptions;
import til.grammar;

alias NamePath = string[];

enum ScopeExitCodes
{
    Proceed,          // keep running
    ReturnSuccess,    // returned without errors
    Failure,          // terminated with errors
    ListSuccess,      // A list was executed with success
}

// Interfaces:
interface ListItem
{
    ulong length();
    string asString();

    ListItem run(Escopo);
    NamePath namePath();

    ScopeExitCodes scopeExit();
    ScopeExitCodes scopeExit(ScopeExitCodes);
}

// Classes:
class List : ListItem
{
    ScopeExitCodes _scopeExit;

    ListItem[] items;
    bool execute = true;

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

    // Utilities and operators:
    override string toString()
    {
        string s = this.asString;
        if (execute)
        {
            return "[" ~ s ~ "]";
        }
        else {
            return "{" ~ s ~ "}";
        }
    }
    ListItem opIndex(int i)
    {
        return items[i];
    }
    ListItem opIndex(ulong i)
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

    // Methods:
    string asString()
    {
        return to!string(this.items
            .map!(x => to!string(x))
            .joiner(" "));
    }
    @property
    ScopeExitCodes scopeExit()
    {
        return this._scopeExit;
    }
    @property
    final ScopeExitCodes scopeExit(ScopeExitCodes code)
    {
        _scopeExit = code;
        return code;
    }

    ListItem run(Escopo escopo)
    {
        writeln("Running ", this);

        // SubLists are not executed:
        if (!execute)
        {
            return this;
        }

        // How to run a list:
        // 1- Run every item in the list:
        // Atoms and string will eventually substitute.
        // ExecLists will be run.
        // SubLists will return themselves.
        // 
        // 2- Get the "command" and try to run it.
        // If it's not a proper command, just return `this`.

        // ----- 1 -----
        ListItem[] newItems;
        ListItem result;

        foreach(item; items)
        {
            result = item.run(escopo);
            writeln(" ", item, " → ", result, "\t\t\t", result.scopeExit);

            final switch(result.scopeExit)
            {
                case ScopeExitCodes.Proceed:
                    break;

                // -----------------
                // Proc execution:
                case ScopeExitCodes.ReturnSuccess:
                    // Our caller don't have to break!
                    result.scopeExit = ScopeExitCodes.ListSuccess;
                    return result;

                case ScopeExitCodes.Failure:
                    throw new Exception("Failure: " ~ to!string(item));

                // -----------------
                // List execution:
                case ScopeExitCodes.ListSuccess:
                    // We don't have to break!
                    result.scopeExit = ScopeExitCodes.Proceed;
                    break;
            }
            newItems ~= result;
        }

        if (newItems.length == 0)
        {
            return new List();
        }

        // ----- 2 -----
        ListItem head = newItems[0];
        auto tail = new List(items[1..$]);

        // lists.order 3 4 1 2
        NamePath cmd = head.namePath;
        ListItem cmdResult = escopo.run_command(cmd, tail);
        if (cmdResult !is null)
        {
            return cmdResult;
        }
        else {
            return result;
        }
    }

    NamePath namePath()
    {
        return ["<LIST>"];
    }
}

class String : ListItem
{
    ScopeExitCodes _scopeExit;

    string[] parts;
    string[int] substitutions;

    this(string s)
    {
        this.parts ~= s;
    }
    this(string[] parts, string[int] substitutions)
    {
        this.parts = parts;
        this.substitutions = substitutions;
    }

    // Operators:
    ulong length()
    {
        return 1;
    }
    override string toString()
    {
        return '"' ~ to!string(this.parts
            .map!(x => to!string(x))
            .joiner("^")) ~ '"';
    }

    // Methods:
    @property
    ScopeExitCodes scopeExit()
    {
        return this._scopeExit;
    }

    @property
    final ScopeExitCodes scopeExit(ScopeExitCodes code)
    {
        _scopeExit = code;
        return code;
    }

    NamePath namePath()
    {
        return ["<STRING>"];
    }

    ListItem run(Escopo escopo)
    {
        if (this.substitutions.length == 0)
        {
            return this;
        }

        string result;
        string subst;
        string value;

        foreach(index, part;parts)
        {
            subst = this.substitutions.get(cast(int)index, null);
            if (subst is null)
            {
                value = part;
            }
            else
            {
                ListItem v = escopo[subst];
                if (v is null)
                {
                    value = "";
                }
                else {
                    value = v.asString;
                }
            }
            result ~= value;
        }

        writeln(" - string " ~ to!string(this) ~ " → " ~ result);
        return new String(result);
    }

    string asString()
    {
        return to!string(this.parts
            .map!(x => to!string(x))
            .joiner(""));
    }
}

class Atom : ListItem
{
    int integer;
    float floatingPoint;
    bool boolean;
    string repr;
    NamePath _namePath;
    ScopeExitCodes _scopeExit;

    this(string s)
    {
        this.repr = s;
    }
    this(List l)
    {
        this.repr = to!string(l);
    }

    // Utilities and operators:
    override string toString()
    {
        return ":" ~ this.repr;
    }
    string debugRepr()
    {
        string result = "";
        result ~= "int:" ~ to!string(this.integer) ~ ";";
        result ~= "float:" ~ to!string(this.floatingPoint) ~ ";";
        result ~= "bool:" ~ to!string(this.boolean) ~ ";";
        result ~= "string:" ~ this.repr;
        return result;
    }
    ulong length()
    {
        return 1;
    }

    // Methods:
    @property
    ScopeExitCodes scopeExit()
    {
        return this._scopeExit;
    }

    @property
    final ScopeExitCodes scopeExit(ScopeExitCodes code)
    {
        this._scopeExit = code;
        return code;
    }

    ListItem run(Escopo escopo)
    {
        if (this.repr[0..1] == "$")
        {
            return escopo[this.repr[1..$]];
        }
        else {
            return this;
        }
    }

    string asString()
    {
        return this.repr;
    }

    @property
    NamePath namePath()
    {
        return this._namePath;
    }
    @property
    NamePath namePath(NamePath path)
    {
        this._namePath = path;
        return path;
    }
}
