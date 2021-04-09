module til.nodes;


import std.algorithm.iteration : map, joiner;
import std.range : back, popBack, retro;
import std.array : join;
import std.conv : to;
import std.experimental.logger : error, trace;

import til.exceptions;
import til.ranges;

alias Items = ListItem[];
alias Cmd = string;
alias CommandHandler = CommandResult delegate(Process, Cmd, CommandResult);


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

struct CommandResult
{
    ExitCode exitCode = ExitCode.Proceed;
    int argumentCount = 0;
    int returnedItemsCount = 0;
    Range stream = null;

    ListItem[] arguments(Process escopo)
    {
        return escopo.pop(argumentCount);
    }
    void push(Process escopo, ListItem item)
    {
        escopo.push(item);
        returnedItemsCount++;
    }
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

class Process
{
    SubProgram program;
    Process parent;

    ListItem[] stack;
    ListItem[string] variables;

    this(Process parent)
    {
        this.parent = parent;
        this.program = parent.program;
    }
    this(Process parent, SubProgram program)
    {
        this.parent = parent;
        this.program = program;
    }

    // The "heap":
    // auto x = escopo["x"];
    ListItem opIndex(string name)
    {
        ListItem value = this.variables.get(name, null);
        if (value is null && this.parent !is null)
        {
            return this.parent[name];
        }
        else
        {
            return value;
        }
    }
    // escopo["x"] = new Atom(123);
    void opIndexAssign(ListItem value, string name)
    {
        variables[name] = value;
    }

    // The Stack:
    /*
       You see, for the user it doesn't really matter
       how we implement this, so we use the back
       of an Array as the top of the stack, but
       doing otherwise wouldn't be noticed
       by anyone.
    */
    ListItem pop()
    {
        auto item = this.stack.back;
        this.stack.popBack();
        trace("POPPED:", item);
        return item;
    }
    ListItem[] pop(int count)
    {
        ListItem[] items;
        for(int i = 0; i < count; i++)
        {
            // TODO: check if we reached stack bottom.
            items ~= this.pop();
        }
        return items;
    }
    void push(ListItem item)
    {
        trace("PUSH:", item);
        this.stack ~= item;
    }

    // Debugging information about itself:
    override string toString()
    {
        string s = "Process(" ~ program.name ~ "):\n";

        s ~= "STACK:" ~ to!string(stack) ~ "\n";
        foreach(name, value; variables)
        {
            s ~= " " ~ name ~ "=<" ~ to!string(value) ~">\n";
        }

        s ~= "COMMANDS:\n";
        foreach(name; program.commands.byKey)
        {
            s ~= " " ~ name ~ " ";
        }
        s ~= "\n";
        return s;
    }

    CommandResult run()
    {
        CommandResult result;
        // TODO: check if this.program !is null
        return this.run(this.program, result);
    }
    CommandResult run(SubProgram subprogram)
    {
        CommandResult result;
        return this.run(subprogram, result);
    }
    CommandResult run(SubProgram subprogram, CommandResult lastResult)
    {
        foreach(pipeline; subprogram.pipelines)
        {
            trace("running next pipeline");
            trace("running pipeline:", pipeline);
            lastResult = pipeline.run(this, lastResult);
            trace("  pipeline.result:", lastResult);

            final switch(lastResult.exitCode)
            {
                case ExitCode.Undefined:
                    throw new Exception(to!string(pipeline) ~ " returned Undefined");

                case ExitCode.Proceed:
                    // That is the expected result.
                    // So we just proceed.
                    break;

                // -----------------
                // Proc execution:
                case ExitCode.ReturnSuccess:
                    // ReturnSuccess is received here when
                    // we are still INSIDE A PROC.
                    // We return the result, but out caller
                    // doesn't necessarily have to break:
                    lastResult.exitCode = ExitCode.CommandSuccess;
                    return lastResult;

                case ExitCode.Failure:
                    throw new Exception("Failure: " ~ to!string(lastResult));

                // -----------------
                // Loops:
                case ExitCode.Break:
                case ExitCode.Continue:
                    return lastResult;

                // -----------------
                // Pipeline execution:
                case ExitCode.CommandSuccess:
                    throw new Exception(
                        to!string(pipeline) ~ " returned CommandSuccess."
                        ~ " Expected a Proceed exit code."
                    );
            }
        }

        // Returns the result of the last expression:
        trace("SubProgram.RETURNING ", lastResult);
        return lastResult;
    }

    ListItem runSubprocess(SubProgram subprogram)
    {
        auto subprocess = new Process(this, subprogram);
        subprocess.run();
        // It's expected to find the result
        // as the last item in the stack:
        return subprocess.pop();
    }

    // Commands
    CommandHandler getCommand(string name)
    {
        return this.getCommand(name, true);
    }
    CommandHandler getCommand(string name, bool tryGlobal)
    {
        /*
        This codebase is not much inclined to
        *early returns*, but in this case
        that is the option that makes
        more sense.
        */

        // Local command:
        CommandHandler handler = this.program.commands.get(name, null);
        if (handler !is null) return handler;

        // Global command:
        if (tryGlobal)
        {
            handler = this.program.globalCommands.get(name, null);
            if (handler !is null) return handler;
        }

        // Parent:
        if (this.parent !is null)
        {
            trace(
                ">>> SEARCHING FOR COMMAND ",
                name,
                " IN PARENT SCOPE <<<"
            );
            handler = parent.getCommand(name, false);
            if (handler !is null) return handler;
        }

        error("Command not found: " ~ name);
        return null;
    }
}

class SubProgram
{
    string name = "<SubProgram>";
    Pipeline[] pipelines;

    CommandHandler[string] commands;
    static CommandHandler[string] globalCommands;

    static CommandHandler[string][string] availableModules;

    this(Pipeline[] pipelines)
    {
        this.pipelines = pipelines;
    }

    void registerGlobalCommands(CommandHandler[string] commands)
    {
        foreach(key, value; commands)
        {
            this.globalCommands[key] = value;
        }
    }
    void addModule(string key, CommandHandler[string] commands)
    {
        availableModules[key] = commands;
    }

    // TODO : improve it with information useful for debugging:
    override string toString()
    {
        string s = "SubProgram " ~ this.name ~ ":\n";
        foreach(pipeline; pipelines)
        {
            s ~= to!string(pipeline) ~ "\n";
        }
        return s;
    }
    string asString()
    {
        return to!string(pipelines
            .map!(x => x.asString)
            .joiner("\n"));
    }
}

class Pipeline
{
    /*
    >>cmd1 a b > cmd2 > cmd3 x<<
    */
    Command[] commands;

    this(Command[] commands)
    {
        this.commands = commands;
    }

    override string toString()
    {
        return "<<" ~ this.asString ~ ">>";
    }
    string asString()
    {
        return to!string(commands
            .map!(x => to!string(x))
            .joiner(" > "));
    }

    CommandResult run(Process escopo, CommandResult lastResult)
    {
        foreach(command; commands)
        {
            trace("running command:", command);
            lastResult = command.run(escopo, lastResult);
            trace("  result: ", lastResult);

            final switch(lastResult.exitCode)
            {
                case ExitCode.Undefined:
                    throw new Exception(to!string(command) ~ " returned Undefined");

                case ExitCode.Proceed:
                    throw new InvalidException(
                        "Commands should not return `Proceed`: " ~ to!string(lastResult));

                // -----------------
                // Proc execution:
                case ExitCode.ReturnSuccess:
                    // ReturnSuccess is received here when
                    // we are still INSIDE A PROC.
                    // We return the result, but out caller
                    // doesn't necessarily have to break:
                    return lastResult;

                case ExitCode.Failure:
                    throw new Exception("Failure: " ~ to!string(lastResult));

                // -----------------
                // Loops:
                case ExitCode.Break:
                case ExitCode.Continue:
                    return lastResult;

                // -----------------
                // List execution:
                case ExitCode.CommandSuccess:
                    // pass
                    break;
            }
        }
        // The expected result of a pipeline is "Proceed".
        lastResult.exitCode = ExitCode.Proceed;
        return lastResult;
    }
}

class Command
{
    string name;
    Items arguments;

    this(string name, Items arguments)
    {
        this.name = name;
        this.arguments = arguments;
        trace("new Command:", name, " ", arguments);
    }

    override string toString()
    {
        // return "cmd(" ~ this.name ~ to!string(this.arguments) ~ ")";
        return "cmd(" ~ this.name ~ ")";
    }

    CommandResult run(Process escopo, CommandResult lastResult)
    {
        trace("Command.run");
        trace(" inside Process ", escopo);
        // Evaluate and push each argument, starting from
        // the last one:
        lastResult.argumentCount = 0;
        trace(" pushing arguments");
        trace(this.arguments);
        foreach(argument; this.arguments.retro)
        {
            trace(" ", argument);
            lastResult.argumentCount++;
            escopo.push(argument.evaluate(escopo));
        }

        // Run the command:
        trace(" finding handler for ", this.name);
        auto handler = escopo.getCommand(this.name);
        if (handler is null)
        {
            error("Command not found: " ~ this.name);
            lastResult.exitCode = ExitCode.Failure;
            return lastResult;
        }

        // We set the exitCode to Undefined as a fla
        // to check if the hander is really doing
        // the basics, at least.
        lastResult.exitCode = ExitCode.Undefined;
        trace(" calling handler...");
        lastResult = handler(escopo, this.name, lastResult);

        // XXX : this is a kind of "sefaty check".
        // It would be nice to NOT run this part
        // in "release" code.
        if (lastResult.exitCode == ExitCode.Undefined)
        {
            throw new Exception(
                "Command "
                ~ to!string(name)
                ~ " returned Undefined. The implementation"
                ~ " is probably wrong."
            );
        }
        return lastResult;
    }

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

    ListItem evaluate(Process escopo, bool force) {return this.evaluate(escopo);}
    ListItem evaluate(Process escopo) {return null;}
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

    override ListItem evaluate(Process escopo)
    {
        auto result = escopo.run(this.subprogram);
        // TODO : evaluate result, somehow.
        return escopo.pop();
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

    override ListItem evaluate(Process escopo)
    {
        return this.evaluate(escopo, false);
    }
    override ListItem evaluate(Process escopo, bool force)
    {
        if (!force)
        {
            return this;
        }
        else
        {
            return new ExecList(this.subprogram).evaluate(escopo);
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
        return "(" ~ to!string(this.items) ~ ")";
    }

    override ListItem evaluate(Process escopo, bool force)
    {
        if (!force)
        {
            return this.evaluate(escopo);
        }
        else
        {
            return this.forceEvaluate(escopo);
        }
    }
    override ListItem evaluate(Process escopo)
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
        return this;
    }
    ListItem forceEvaluate(Process escopo)
    {
        ListItem[] items;
        foreach(item; this.items)
        {
            items ~= item.evaluate(escopo);
        }
        return new SimpleList(items);
    }
}

// A string without substitutions:
class String : ListItem
{
}

class SimpleString : String
{
    string repr;

    this(string s)
    {
        this.repr = s;
        this.type = ObjectTypes.String;
    }

    // Operators:
    override string toString()
    {
        return '"' ~ this.repr ~ '"';
    }

    override ListItem evaluate(Process escopo)
    {
        return this;
    }

    override string asString()
    {
        return this.repr;
    }
    override int asInteger()
    {
        throw new Exception("Cannot convert a String into an integer");
    }
    override float asFloat()
    {
        throw new Exception("Cannot convert a String into a float");
    }
    override bool asBoolean()
    {
        throw new Exception("Cannot convert a String into a boolean");
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
        return new SimpleString(newRepr);
    }
}

class SubstString : SimpleString
{
    string[] parts;
    string[int] substitutions;

    this(string[] parts, string[int] substitutions)
    {
        super("");
        this.parts = parts;
        this.substitutions = substitutions;
        this.type = ObjectTypes.String;
    }

    // Operators:
    override string toString()
    {
        return '"' ~ to!string(this.parts
            .map!(x => to!string(x))
            .joiner("")) ~ '"';
    }

    override ListItem evaluate(Process escopo)
    {
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
        return new SimpleString(result);
    }

    override string asString()
    {
        return to!string(this.parts.joiner(""));
    }
}

class Atom : ListItem
{
    int integer;
    float floatingPoint;
    bool boolean;
    string _repr;
    bool hasSubstitution = true;

    this(string s)
    {
        this.repr = s;
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
        this.hasSubstitution = false;
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
        return this._repr;

    }
    @property
    string repr(string s)
    {
        this._repr = s;

        this.hasSubstitution = (
            s[0] == '$' || s.length >= 3 && s[0] == '-' && s[1] == '$'
        );

        return s;
    }

    override ListItem evaluate(Process escopo)
    {
        if (!this.hasSubstitution)
        {
            return this;
        }

        string repr = this.repr;
        char firstChar = repr[0];
        if (firstChar == '$')
        {
            string key = repr[1..$];
            auto value = escopo[key];
            if (value is null)
            {
                throw new Exception(
                    "Key not found: " ~ key
                );
            }
            else
            {
                return value;
            }
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
            this.hasSubstitution = false;
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
    override bool asBoolean()
    {
        if (this.type == ObjectTypes.Boolean)
        {
            return this.boolean;
        }
        else
        {
            throw new Exception(
                "Cannot convert a "
                ~ to!string(this.type)
                ~ " into a boolean"
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
