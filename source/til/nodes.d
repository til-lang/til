module til.nodes;


import std.array : join;
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

enum ObjectTypes
{
    Undefined,
    List,
    String,
    Name,
    Atom,
    Float,
    Integer,
    Boolean
}


// A base class for all kind of items that
// compose a list (including Lists):
class ListItem
{
    ObjectTypes type = ObjectTypes.Undefined;
    ulong defaultLength = 0;
    string objectNAME = "BASEITEM";
    ScopeExitCodes _scopeExit;
    string[] _namePath;

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
    @property
    NamePath namePath(string name)
    {
        auto path = [name];
        this._namePath = path;
        return path;
    }

    /*
    {
        {a b c}
        d e f
        {g h i}
    } → a b c d e f g h i
    */
    ListItem[] atoms()
    {
        ListItem[] a;
        // List.items returns ListItem[]
        // Anything else returns null.
        foreach(item; this.items)
        {
            auto subItems = item.items;
            if (subItems is null)
            {
                a ~= item;
            }
            else {
                a ~= item.atoms;
            }
        }
        return a;
    }

    // Stubs:
    ulong length() {return defaultLength;}
    string asString() {return objectNAME;}
    ListItem run(Escopo escopo)
    {
        return this.run(escopo, false);
    }
    ListItem run(Escopo escopo, bool isMain) {return null;}
    ListItem[] items() {return null;}
}


class List : ListItem
{
    ListItem[] _items;
    bool execute = false;

    this()
    {
    }
    this(ListItem item)
    {
        this._items ~= item;
    }
    this(ListItem item, bool execute)
    {
        this._items ~= item;
        this.execute = execute;
    }
    this(ListItem[] items)
    {
        this._items = items;
    }
    this(ListItem[] items, bool execute)
    {
        this._items = items;
        this.execute = execute;
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
        return _items[i];
    }
    ListItem opIndex(ulong i)
    {
        return _items[i];
    }
    ListItem[] opSlice(ulong start, ulong end)
    {
        return _items[start..end];
    }
    override ulong length()
    {
        return _items.length;
    }
    @property ulong opDollar()
    {
        return this.length;
    }

    // Methods:
    override string asString()
    {
        return to!string(this._items
            .map!(x => to!string(x))
            .joiner(" "));
    }

    override ListItem[] items()
    {
        return this._items;
    }

    ListItem[] evaluate(Escopo escopo)
    {
        ListItem[] newItems;
        // TODO: check if this list is a SubList or not.
        // (maybe?)

        foreach(item; _items)
        {
            newItems ~= item.run(escopo);
        }

        return newItems;
    }

    override ListItem run(Escopo escopo, bool isMain)
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

        foreach(item; _items)
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
                    // ReturnSuccess is received here when
                    // we are still INSIDE A PROC.
                    // We return the result, but out caller
                    // doesn't have to break:
                    result.scopeExit = ScopeExitCodes.ListSuccess;
                    return result;

                case ScopeExitCodes.Failure:
                    throw new Exception("Failure: " ~ to!string(item));

                // -----------------
                // List execution:
                case ScopeExitCodes.ListSuccess:
                    result.scopeExit = ScopeExitCodes.Proceed;
                    // TESTE
                    // break;
                    return result;
            }
            newItems ~= result;
        }

        if (isMain)
        {
            return result;
        }

        if (newItems.length == 0)
        {
            // Unreachable???
            writeln(" ", this, ".run RETURNED EMPTY LIST!");
            return new List();
        }

        // ----- 2 -----
        writeln(" -- newItems: ", newItems);
        ListItem head = newItems[0];

        writeln(" List.run.head:", head);
        // auto tail = new List(_items[1..$]);
        auto tail = new List(newItems[1..$]);

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
}

class String : ListItem
{
    ulong defaultLength = 1;
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
    override string toString()
    {
        return '"' ~ to!string(this.parts
            .map!(x => to!string(x))
            .joiner("")) ~ '"';
    }

    override ListItem run(Escopo escopo)
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

    override string asString()
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
    string _repr;
    ulong defaultLength = 1;
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

    // Methods:
    @property
    string repr()
    {
        if (this._repr is null)
        {
            this._repr = this.namePath.join(".");
        }
        return this._repr;

    }
    @property
    string repr(string s)
    {
        this._repr = s;
        this._namePath = [s];
        return s;
    }

    override ListItem run(Escopo escopo)
    {
        if (this.repr[0..1] == "$")
        {
            return escopo[this.repr[1..$]];
        }
        else {
            return this;
        }
    }

    override string asString()
    {
        return this.repr;
    }
}
