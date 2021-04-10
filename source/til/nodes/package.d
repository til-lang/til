module til.nodes;

public import std.algorithm.iteration : map, joiner;
public import std.range : back, popBack, retro;
public import std.array : join;
public import std.conv : to;
public import std.experimental.logger : error, trace;

public import til.exceptions;
// import til.ranges;

public import til.context;
public import til.nodes.process;
public import til.nodes.subprogram;
public import til.nodes.pipeline;
public import til.nodes.command;
public import til.nodes.string;
public import til.nodes.atom;

alias Items = ListItem[];
alias Cmd = string;
alias CommandHandler = CommandContext delegate(Cmd, CommandContext);


enum ExitCode
{
    Undefined,
    Proceed,          // keep running
    ReturnSuccess,    // returned without errors
    Failure,          // terminated with errors
    CommandSuccess,   // A command was executed with success
    Break,            // Break the current loop
    Continue,         // Continue to the next iteraction
}

enum ObjectTypes
{
    Undefined,
    List,
    String,
    Name,
    Atom,
    Operator,
    Float,
    Integer,
    Boolean,
}


// A base class for all kind of items that
// compose a list (including Lists):
class ListItem
{
    ObjectTypes type;

    // Stubs:
    abstract string asString();
    abstract int asInteger();
    abstract float asFloat();
    abstract bool asBoolean();
    abstract ListItem inverted();

    CommandContext evaluate(CommandContext context, bool force) {return this.evaluate(context);}
    CommandContext evaluate(CommandContext context) {return context;}
}

// Base class for lists:
class BaseList : ListItem
{
    Items items;

    this()
    {
        this([]);
    }
    this(ListItem item)
    {
        this([item]);
    }
    this(Items items)
    {
        this.items = items;
        this.type = ObjectTypes.List;
    }

    // Methods:
    override string asString()
    {
        string s = to!string(this.items
            .map!(x => x.asString)
            .joiner(" "));
        return "BaseList:(" ~ s ~ ")";
    }
    override int asInteger()
    {
        // XXX : or can we???
        throw new Exception("Cannot convert a List into an integer");
    }
    override float asFloat()
    {
        // XXX : or can we???
        throw new Exception("Cannot convert a List into a float");
    }
    override bool asBoolean()
    {
        // XXX : or can we???
        throw new Exception("Cannot convert a List into a boolean");
    }
    override ListItem inverted()
    {
        throw new Exception("Cannot invert a List!");
        // XXX : or can?
        // XXX : should we?
    }
}

class ExecList : BaseList
{
    SubProgram subprogram;

    this(SubProgram subprogram)
    {
        super();
        this.subprogram = subprogram;
    }

    // Utilities and operators:
    override string toString()
    {
        string s = this.subprogram.asString;
        return "[" ~ s ~ "]";
    }

    override CommandContext evaluate(CommandContext context)
    {
        return context.escopo.run(this.subprogram, context);
    }
}

class SubList : BaseList
{
    SubProgram subprogram;

    this(SubProgram subprogram)
    {
        super();
        this.subprogram = subprogram;
    }

    // -----------------------------
    // Utilities and operators:
    override string toString()
    {
        string s = this.subprogram.asString;
        return "{" ~ s ~ "}";
    }

    override CommandContext evaluate(CommandContext context)
    {
        return this.evaluate(context, false);
    }
    override CommandContext evaluate(CommandContext context, bool force)
    {
        if (!force)
        {
            context.push(this);
            return context;
        }
        else
        {
            return new ExecList(this.subprogram).evaluate(context);
        }
    }
}

class SimpleList : BaseList
{
    /*
       A SimpleList contains only ONE List inside it.
       Its primary use is for passing parameters
       for `if`, for instance, like
       if ($x > 10) {...}
       Also, its asInteger, asFloat and asBoolean methods
       must be implemented (so that `if`, for instance,
       can simply call it without much worries).
    */

    this(Items items)
    {
        super();
        this.items = items;
    }

    // -----------------------------
    // Utilities and operators:
    override string toString()
    {
        return "(" ~ this.asString ~ ")";
    }
    override string asString()
    {
        return to!string(this.items
            .map!(x => x.asString)
            .joiner(" "));
    }

    override CommandContext evaluate(CommandContext context, bool force)
    {
        if (!force)
        {
            return this.evaluate(context);
        }
        else
        {
            return this.forceEvaluate(context);
        }
    }
    override CommandContext evaluate(CommandContext context)
    {
        /*
        Returning itself has some advantages:
        1- We can use SimpleLists as "liquid" lists
        the same way as SubLists (if a proc returns only
        a SimpleList it is "diluted" in the CommonList
        that called it as a command, like in
        set eagle [f 15 E]
         → set eagle "strike" "eagle"
        2- It is more suitable to return SimpleLists
        instead of SubLists because semantically
        the returns are only one list, not
        a list of lists.
        */
        context.push(this);
        context.exitCode = ExitCode.Proceed;
        return context;
    }
    CommandContext forceEvaluate(CommandContext context)
    {
        context.size = 0;
        foreach(item; this.items.retro)
        {
            context.run(&(item.evaluate));
        }

        /*
        What resides in the stack, at the end, is not
        the items inside the original SimpleLists,
        but a new SimpleLists with its original
        items already evaluated. We are only
        using the stack as temporary space.
        */
        auto newList = new SimpleList(context.items);
        context.push(newList);
        return context;
    }
}
