module til.process;

import std.array : join, split;
import std.container : DList;

import til.modules;
import til.nodes;
import til.procedures;
import til.scheduler;

debug
{
    import std.stdio;
}

enum ProcessState
{
    New,
    Running,
    Receiving,
    Waiting,
    Finished,
}


class NotFoundError : Exception
{
    this(string msg)
    {
        super(msg);
    }
}


abstract class Runnable
{
    string name;
    this(string name)
    {
        this.name = name;
    }

    abstract Context run(string path, Context context);

    override string toString()
    {
        return "Runnable " ~ this.name;
    }
}


class Process
{
    SubProgram program;
    Process parent;

    auto state = ProcessState.New;

    ListItem[64] stack;
    ulong stackPointer = 0;
    Items[string] variables;
    Items[string] internalVariables;
    CommandsMap commands;

    // PIDs
    static uint counter = 0;
    string description;
    uint index;

    // Scheduling
    Scheduler scheduler = null;

    // Piping
    Item input = null;
    Item output = null;

    this(Process parent, bool shareStack=false)
    {
        this.index = this.counter++;
        this.parent = parent;

        if (parent !is null)
        {
            this.input = parent.input;
            this.output = parent.output;
            this.program = parent.program;

            if (shareStack)
            {
                this.stack = parent.stack[];
                this.stackPointer = parent.stackPointer;
            }
        }
    }
    this(Process parent, SubProgram program)
    {
        this(parent);
        this.program = program;
    }

    static Process clone(Process other)
    {
        auto p = new Process(other);

        p.stack = other.stack;
        p.stackPointer = other.stackPointer;
        p.commands = other.commands;

        return p;
    }

    // The "heap":
    // auto x = escopo["x"];
    Items opIndex(string name)
    {
        Items* value = (name in this.variables);
        if (value is null)
        {
            if (this.parent !is null)
            {
                return this.parent[name];
            }
            else
            {
                throw new NotFoundError("`" ~ name ~ "` variable not found!");
            }
        }
        else
        {
            return *value;
        }
    }
    // escopo["x"] = new Atom(123);
    void opIndexAssign(ListItem value, string name)
    {
        debug {stderr.writeln(name, " = ", value);}
        variables[name] = [value];
    }
    void opIndexAssign(Items value, string name)
    {
        debug {stderr.writeln(name, " = ", value);}
        variables[name] = value;
    }

    // Scheduler-related things
    void yield()
    {
        this.getRoot().scheduler.yield();
    }

    // The Stack:
    string stackAsString()
    {
        if (stackPointer == 0) return "empty";
        return to!string(stack[0..stackPointer]);

    }

    ListItem peek(uint index=1)
    {
        /*
        Just LOOK at the first item, do
        not pop it off.
        */
        long pointer = stackPointer - index;
        if (pointer < 0)
        {
            return null;
        }
        return stack[pointer];
    }
    ListItem pop()
    {
        auto item = stack[--stackPointer];
        return item;
    }
    Items pop(int count)
    {
        return this.pop(cast(ulong)count);
    }
    Items pop(ulong count)
    {
        Items items;
        foreach(i; 0..count)
        {
            items ~= pop();
        }
        return items;
    }
    void push(ListItem item)
    {
        stack[stackPointer++] = item;
    }
    template push(T : int)
    {
        void push(T x)
        {
            return push(new IntegerAtom(x));
        }
    }
    template push(T : long)
    {
        void push(T x)
        {
            return push(new IntegerAtom(x));
        }
    }
    template push(T : float)
    {
        void push(T x)
        {
            return push(new FloatAtom(x));
        }
    }
    template push(T : bool)
    {
        void push(T x)
        {
            return push(new BooleanAtom(x));
        }
    }
    template push(T : string)
    {
        void push(T x)
        {
            return push(new NameAtom(x));
        }
    }

    // Utilities:
    Process getRoot()
    {
        if (this.scheduler !is null)
        {
            return this;
        }
        else if (this.parent !is null)
        {
            return this.parent.getRoot();
        }
        else
        {
            return null;
        }
    }

    // Debugging information about itself:
    override string toString()
    {
        string s = (
            "Process["
            ~ to!string(this.index)
            ~ ":" ~ this.description
            ~ "]\n"
        );
        s ~= to!string(variables.byKey) ~ "\n";
        s ~= to!string(commands.byKey) ~ "\n";

        return s;
    }

    // Commands and procedures
    Command getCommand(string name)
    {
        Command cmd;

        // If it's a local command:
        auto c = (name in commands);
        if (c !is null) return *c;

        // It it's present on parent:
        if (this.parent !is null)
        {
            cmd = parent.getCommand(name);
            if (cmd !is null)
            {
                commands[name] = cmd;
                return cmd;
            }
        }

        // If the command is present in an external module:
        bool success = {
            // std.io.out → std.io
            string modulePath = to!string(name.split(".")[0..$-1].join("."));

            // std.math
            // = std.math
            // exec
            // = exec
            if (this.importModule(name, name)) return true;

            // std.io.out
            // = std.io
            if (this.importModule(modulePath)) return true;

            // io.out
            // = std.io as io
            if (this.importModule("std." ~ modulePath, modulePath)) return true;

            // math
            // = std.math as math
            if (this.importModule("std." ~ name, name)) return true;

            return false;
        }();

        if (success) {
            // We imported the module, but we're not sure if this
            // name actually exists inside it:
            // (Important: do NOT call this method recursively!)
            c = (name in commands);
            if (c !is null)
            {
                commands[name] = *c;
            }
        }

        // If such command doesn't seem to exist, `cmd` will be null:
        return cmd;
    }

    // Execution
    Context run()
    {
        auto context = Context(this);
        if (this.program is null)
        {
            throw new Exception("Process.program cannot be null");
        }
        return this.run(this.program, context);
    }
    Context run(SubProgram subprogram)
    {
        auto context = Context(this);
        return this.run(subprogram, context);
    }
    Context run(SubProgram subprogram, Context context)
    {
        this.state = ProcessState.Running;

        foreach(index, pipeline; subprogram.pipelines)
        {
            context = pipeline.run(context);

            final switch(context.exitCode)
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
                    // ReturnSuccess should keep stopping
                    // processes until properly
                    // handled.
                    return context;

                case ExitCode.Failure:
                    /*
                    Error handling:
                    1- Call **local** procedure `on.error`, if
                       it exists and analyse ITS exitCode.
                    2- Or, if it doesn't exist, return `context`
                       as we would already do.
                    */
                    Command* errorHandler = ("on.error" in commands);
                    if (errorHandler !is null)
                    {
                        debug {
                            stderr.writeln("Calling on.error");
                            stderr.writeln(" context: ", context);
                            stderr.writeln(" ...");
                        }
                        context = (*errorHandler).run("on.error", context);
                        debug {stderr.writeln(" returned context:", context);}
                        /*
                        errorHandler can simply "rethrow"
                        the Error or even return a new
                        one. That's ok. We aren't
                        trying to do anything
                        much fancy, here.
                        */
                    }
                    /*
                    Wheter we called errorHandler or not,
                    we ARE going to exit the current
                    scope right now. The idea of
                    a errorHandler is NOT to
                    allow continuing in the
                    same scope.
                    */
                    return context;

                // -----------------
                // Loops:
                case ExitCode.Break:
                case ExitCode.Continue:
                case ExitCode.Skip:
                    return context;

                // -----------------
                // Pipeline execution:
                case ExitCode.CommandSuccess:
                    throw new Exception(
                        to!string(pipeline) ~ " returned CommandSuccess."
                        ~ " Expected a Proceed exit code."
                    );
            }
            // Each 8 pipelines we yield fiber/thread control:
            if ((index & 0x07) == 0x07) this.yield();
        }

        // Returns the context of the last expression:
        return context;
    }
}
