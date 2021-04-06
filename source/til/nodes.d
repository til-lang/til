module til.nodes;


import std.algorithm.iteration : map, joiner;
import std.array : join;
import std.conv : to;
import std.experimental.logger;

import til.escopo;
import til.exceptions;
import til.ranges;
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
    Parentesis,
    Operator,
    Float,
    Integer,
    Boolean,
}


// A base class for all kind of items that
// compose a list (including Lists):
class ListItem
{
    ObjectTypes type = ObjectTypes.Undefined;
    ulong defaultLength = 0;
    ScopeExitCodes scopeExit;
    string[] _namePath;

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
    abstract string asString();
    abstract int asInteger();
    abstract float asFloat();
    abstract ListItem inverted();

    ListItem run(Escopo escopo) {return null;}
    Range items() {return null;}
}

class BaseList : ListItem
{
    private Range _items;

    this()
    {
        this._items = new StaticItems([]);
    }
    this(ListItem item)
    {
        this._items = new StaticItems([item]);
    }
    this(ListItem[] items)
    {
        this._items = new StaticItems(items);
    }
    this(Range items)
    {
        this._items = items;
    }

    // Methods:
    override string asString()
    {
        return this.items.asString;
    }
    override int asInteger()
    {
        throw new Exception("Cannot convert a List into an integer");
    }
    override float asFloat()
    {
        throw new Exception("Cannot convert a List into an float");
    }

    override ListItem inverted()
    {
        throw new Exception("Cannot invert a List!");
        // XXX : or can?
        // XXX : should we?
    }

    @property
    override Range items()
    {
        return this._items.save();
    }

    // Some utilities:
    static ListItem[] flatten(Range items)
    {
        ListItem[] flattened;

        foreach(item; items)
        {
            auto nextItems = item.items;
            if (nextItems is null)
            {
                // An Atom or String:
                flattened ~= item;
            }
            else
            {
                flattened ~= BaseList.flatten(item.items);
            }
        }

        return flattened;
    }
}

/*
 * A word about lists and how each one should `run`:
 * 
 * A SubList always returns its items, without running them;
 * A CommonList runs each item and returns them;
 * A ExecList runs each item and tries to execute each of
 * them as a command.
 */

class ExecList : BaseList
{
    this()
    {
        super();
    }
    this(ListItem item)
    {
        super(item);
    }
    this(ListItem[] items)
    {
        super(items);
    }
    this(Range items)
    {
        super(items);
    }

    /*
     * A ExecList is how we represent both the program
     * itself and any ExecList.
     */

    // Utilities and operators:
    override string toString()
    {
        string s = this.asString;
        return "[" ~ s ~ "]";
    }

    override ListItem run(Escopo escopo)
    {
        trace("ExecList.run: ", this);
        trace(" scope:", escopo);
        // How to run a program:
        // 1- Run every item in the list:
        // Atoms and string will eventually substitute.
        // ExecLists will be run.
        // SubLists will return themselves.
        // 
        // 2- Get the "command" and try to run it.
        // If it's not a proper command, just return `this`.

        // ----- 1 -----
        ListItem result;

        foreach(item; this.items)
        {
            // Each item is supposed to be a CommonList.
            // So running a CommonList returns a SubList with
            // all substitutions already made:
            auto subList = item.run(escopo);

            trace(
                " ", item, " → ", subList
            );
            // After that, we can already treat the SubList
            // as if it as a command:
            result = runCommand(subList.items, escopo);
            trace(
                " → ", result
            );
            if (result is null)
            {
                /*
                throw new Exception(
                    "Command not found: " ~ to!string(subList)
                );
                */
                // TESTE:
                // TODO: make it throw the Exception.
                result = new SubList();
            }
            trace("result: ", result, " (", result.scopeExit, ")");

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
                    // doesn't necessarily have to break:
                    result.scopeExit = ScopeExitCodes.ListSuccess;
                    return result;

                case ScopeExitCodes.Failure:
                    throw new Exception("Failure: " ~ to!string(item));

                // -----------------
                // List execution:
                case ScopeExitCodes.ListSuccess:
                    result.scopeExit = ScopeExitCodes.Proceed;
                    return result;
            }
        }

        // Return the result of the last "expression":
        trace("ExecLists.RETURNING ", result);
        return result;
    }

    ListItem runCommand(Range items, Escopo escopo)
    {
        trace("nodes.runCommand:", items);
        // ----- 2 -----

        // Backup the contents, in case this is NOT a command.
        // XXX: this part could be improved, probably...
        auto backup = items.save();

        // head : tail
        ListItem head = items.consume();
        auto tail = items;
        trace(" List.run: ", head, " : ", tail);

        // lists.order 3 4 1 2
        NamePath cmd = head.namePath;
        // XXX : is it the correct place to check if we
        // are trying to execute a SubList as if it was
        // a command???
        if (cmd is null)
        {
            // return items[0];  <-- working, but horrendous.
            // XXX: should it be a CommonList, maybe?
            // BUG: HEEEY! We consumed the head, already!
            return new SubList(backup);
        }
        else
        {
            return escopo.runCommand(cmd, tail);
        }
    }
}

class SubList : BaseList
{
    this()
    {
        super();
    }
    this(ListItem item)
    {
        super(item);
    }
    this(ListItem[] items)
    {
        super(items);
    }
    this(Range items)
    {
        super(items);
    }

    // -----------------------------
    // Utilities and operators:
    override string toString()
    {
        string s = this.asString;
        return "{" ~ s ~ "}";
    }

    override ListItem run(Escopo escopo)
    {
        trace("SubList.run: ", this);
        return this;
    }
}

class CommonList : BaseList
{
    this()
    {
        super();
    }
    this(ListItem item)
    {
        super(item);
    }
    this(ListItem[] items)
    {
        super(items);
    }
    this(Range items)
    {
        super(items);
    }

    override string toString()
    {
        string s = this.asString;
        return "(" ~ s ~ ")";
    }
    /*
     * A "Common" List is what goes inside both
     * Programs/ExecLists and SubLists.
     *
     * # (All lines: a program)
     * set x [math.sum 1 2 3]   <- Common List
     *       ^  ^
     *       |  +--- A Common List inside an ExecList
     *       +------ An ExecList
     */

    override ListItem run(Escopo escopo)
    {
        // TODO: create a CHAIN of Ranges.
        trace("CommonList.run: ", this);
        trace(" scope:", escopo);
        Range[] ranges;

        foreach(item; this.items)
        {
            trace(" - item: ", item);
            auto result = item.run(escopo);
            // TODO: evaluate result.scopeExit.
            auto items = result.items();
            if (items is null)
            {
                // An Atom or String
                trace(" CommonList.ranges ← new StaticItems(Atom/String)");
                trace("  ", result);
                ranges ~= new StaticItems(result);
            }
            else if (result != item)
            // else if (result.scopeExit == ScopeExitCodes.ListSuccess)
            {
                // ExecLists should return a CommonList
                // so that we can "expand" the result, here:
                trace(" CommonList.ranges ~= items");
                trace("  ", result, " != ", item);
                ranges ~= items;
            }
            else
            {
                // A proper SubLists, that evaluates to itself:
                trace(" CommonList.ranges ← new StaticItems(SubList)");
                trace("  ", result);
                ranges ~= new StaticItems(result);
            }
        }

        /*
        After evaluation, we shouldn't evaluate
        the resulting List again, so the natural
        thinking would lead to return a SubList.
        HOWEVER, we also want to "expand" ExecLists
        results, so to signal that we should return
        anything that not a SubList (we're going to
        choose a new CommonList.)
        */
        return new CommonList(new ChainedItems(ranges));
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

        trace(" - string " ~ to!string(this) ~ " → " ~ result);
        return new String(result);
    }

    override string asString()
    {
        return to!string(this.parts.joiner(""));
    }
    override int asInteger()
    {
        throw new Exception("Cannot convert a String into an integer");
    }
    override float asFloat()
    {
        throw new Exception("Cannot convert a String into an float");
    }

    override ListItem inverted()
    {
        string newRepr;
        string repr = this.asString;
        if (repr[0] == '-')
        {
            newRepr = repr[1..$];
        }
        else
        {
            newRepr = "-" ~ repr;
        }
        return new String(newRepr);
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
        this._repr = s;
    }
    this(string s, ObjectTypes t)
    {
        this(s);
        this.type = t;
    }
    this(int i)
    {
        this.integer = i;
        this._repr = to!string(i);
        this.type = ObjectTypes.Integer;
    }
    this(float f)
    {
        this.floatingPoint = f;
        this._repr = to!string(f);
        this.type = ObjectTypes.Float;
    }
    this(bool b)
    {
        this.boolean = b;
        this.integer = to!int(b);
        this._repr = to!string(b);
        this.type = ObjectTypes.Boolean;
    }

    // Utilities and operators:
    override string toString()
    {
        return ":" ~ this.repr ~ "(" ~ to!string(this.type) ~ ")";
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
        string repr = this.repr;
        char firstChar = repr[0];
        if (firstChar == '$')
        {
            string key = repr[1..$];
            return escopo[key];
        }
        else if (repr.length >= 3 && firstChar == '-' && repr[1] == '$')
        {
            string key = repr[2..$];
            // set x 10
            // set y -$x
            //  → set y -10
            auto value = escopo[key];
            /*
            It's not a good idea to simply return
            a `new Atom(value.repr)` because we
            don't want to lose information
            about the value, as its
            integer or float
            values...
            */
            return value.inverted;
        }
        else {
            return this;
        }
    }

    override string asString()
    {
        return this.repr;
    }

    override int asInteger()
    {
        switch(this.type)
        {
            case ObjectTypes.Integer:
                return this.integer;
            case ObjectTypes.Float:
                return cast(int)this.floatingPoint;
            default:
                throw new Exception(
                    "Cannot convert a "
                    ~ to!string(this.type)
                    ~ " into an integer"
                );
        }
    }

    override float asFloat()
    {
        switch(this.type)
        {
            case ObjectTypes.Float:
                return this.floatingPoint;
            case ObjectTypes.Integer:
                return cast(float)this.integer;
            default:
                throw new Exception(
                    "Cannot convert a "
                    ~ to!string(this.type)
                    ~ " into a float"
                );
        }
    }


    override ListItem inverted()
    {
        switch(this.type)
        {
            case ObjectTypes.Integer:
                return new Atom(-this.integer);
            case ObjectTypes.Float:
                return new Atom(-this.floatingPoint);
            default:
                throw new Exception(
                    "Atom: don't know how to invert a "
                    ~ to!string(this.type)
                );
        }
    }
}
