module til.process;

import std.array : join, split;
import std.container : DList;

import til.nodes;
import til.modules;
import til.ranges;
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


class ProcessIORange : Range
{
    ListItem buffer;
    Process process;
    string name;

    this(Process process, string name)
    {
        this.process = process;
        this.name = name;
    }

    void write(ListItem item)
    {
        // While someone does not consume...
        while (buffer !is null)
        {
            debug {
                stderr.writeln(
                    "writing ", item,
                    ": ", name, ".buffer is not null: ",
                    buffer,
                    " process: ", process
                );
            }
            this.process.yield();
        }
        buffer = item;
    }

    override bool empty()
    {
        while (process.state != ProcessState.Finished)
        {
            if (buffer !is null) return false;

            // Give the process a change to terminate
            // or send something to the pipe:
            debug {
                stderr.writeln(
                    "empty: ", name, ".buffer is still null"
                );
            }
            process.yield();
        }
        return (buffer is null);
    }
    override ListItem front()
    {
        return this.buffer;
    }
    override void popFront()
    {
        this.buffer = null;
    }
    override string toString()
    {
        return "ProcessIORange " ~ name;
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

    // PIDs
    static uint counter = 0;
    uint index;

    // Scheduling
    Scheduler scheduler = null;

    // Piping
    Range input = null;
    ProcessIORange output = null;

    this(Process parent)
    {
        this.index = this.counter++;
        this.parent = parent;

        if (parent !is null)
        {
            this.input = parent.input;
            this.output = parent.output;
            this.stack = parent.stack[];
            this.stackPointer = parent.stackPointer;
            this.program = parent.program;
        }
    }
    this(Process parent, SubProgram program)
    {
        this(parent);
        this.program = program;
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
                throw new Exception(name ~ " variable not found!");
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

    ListItem peek()
    {
        /*
        Just LOOK at the first item, do
        not pop it off.
        */
        return stack[stackPointer-1];
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
        string s = "Process[" ~ to!string(this.index) ~ "]";
        /*
        s ~= "(" ~ program.name ~ "):\n";

        s ~= "STACK:" ~ stackAsString ~ " SP:" ~ to!string(stackPointer) ~ "\n";
        */
        foreach(name, value; variables)
        {
            // s ~= " " ~ name ~ "=<" ~ to!string(value) ~">\n";
            s ~= " " ~ name ~ "\n";
        }

        s ~= "COMMANDS:\n";
        foreach(name; program.commands.byKey)
        {
            s ~= " " ~ name ~ " ";
        }
        s ~= "\n";
        return s;
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

        debug {stderr.writeln("getCommand ", name, " in ", this);}

        CommandHandler* handler;

        // Local command:
        handler = (name in this.program.commands);
        if (handler !is null) return *handler;

        // Global command:
        if (tryGlobal)
        {
            handler = (name in this.program.globalCommands);
            if (handler !is null)
            {
                // Save in "cache":
                this.program.commands[name] = *handler;
                return *handler;
            }
        }

        // Parent:
        if (this.parent !is null)
        {
            auto h = parent.getCommand(name, false);
            if (h !is null)
            {
                this.program.commands[name] = h;
                return h;
            }
        }

        /*
        name: std.math.run
        Prefix: std.math
        Let's try to autoimport!
        */
        bool success = {
            string modulePath = to!string(name.split(".")[0..$-1].join("."));

            // -------------------------
            // 1- From builtin sources:

            // std.io.out
            // = std.io
            if (program.importModule(modulePath)) return true;

            // io.out
            // = std.io as io
            if (program.importModule("std." ~ modulePath, modulePath)) return true;

            // std.math
            // = std.math
            if (program.importModule(name, name)) return true;

            // math
            // = std.math as math
            if (program.importModule("std." ~ name, name)) return true;

            // -------------------------
            // 2- From shared libraries:
            // std.io.out
            // = std.io
            if (program.importModuleFromSharedLibrary(modulePath)) return true;

            // io.out
            // = std.io as io
            if (program.importModuleFromSharedLibrary("std." ~ modulePath, modulePath)) return true;

            // std.math
            // = std.math
            if (program.importModuleFromSharedLibrary(name, name)) return true;

            // math
            // = std.math as math
            if (program.importModuleFromSharedLibrary("std." ~ name, name)) return true;

            return false;
        }();

        if (success) {
            // We imported the module, but we're not sure if this
            // name actually exists inside it:
            // (Important: do NOT call this method recursively!)
            handler = (name in this.program.commands);
            if (handler !is null) return *handler;
        }
        return null;
    }

    // Execution
    CommandContext run()
    {
        auto context = CommandContext(this);
        if (this.program is null) {throw new Exception("process.program cannot be null");}
        return this.run(this.program, context);
    }
    CommandContext run(SubProgram subprogram)
    {
        auto context = CommandContext(this);
        return this.run(subprogram, context);
    }
    CommandContext run(SubProgram subprogram, CommandContext context)
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
                    1- Call **local** procedure `error.handler`, if
                       it exists and analyse ITS exitCode.
                    2- Or, if it doesn't exist, return `context`
                       as we would already do.
                    */
                    CommandHandler* errorHandler = ("error.handler" in subprogram.commands);
                    if (errorHandler !is null)
                    {
                        debug {
                            stderr.writeln("Calling error.handler");
                            stderr.writeln(" context: ", context);
                        }
                        context = (*errorHandler)("error.handler", context);
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
