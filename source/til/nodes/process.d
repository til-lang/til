module til.nodes.process;

import std.array : join, split;
import std.container : DList;
import til.nodes;
import til.modules;


class Process
{
    static uint counter = 0;
    uint index;
    SubProgram program;
    Process parent;

    ListItem[64] stack;
    ulong stackPointer = 0;
    Items[string] variables;

    this(Process parent)
    {
        this.index = this.counter++;
        this.parent = parent;
        if (parent !is null)
        {
            this.stack = parent.stack;
            trace(" >>> STACK COPY ALERT <<<");
            this.program = parent.program;
        }
        else
        {
            // Pre-allocate some space in the stack:
            // stack.reserve = 50;
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
        Items value = this.variables.get(name, null);
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
        variables[name] = [value];
    }
    void opIndexAssign(Items value, string name)
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
    ListItem peek()
    {
        /*
        Just look at the first item, do
        not pop it off.
        */
        return stack[stackPointer-1];
    }
    ListItem pop()
    {
        return stack[--stackPointer];
    }
    ListItem[] pop(int count)
    {
        return this.pop(cast(ulong)count);
    }
    ListItem[] pop(ulong count)
    {
        ListItem[] items;
        for(ulong i = 0; i < count; i++)
        {
            // TODO: check if we reached stack bottom.
            items ~= this.pop();
        }
        return items;
    }
    void push(ListItem item)
    {
        trace("PUSHED ", item, " at ", stackPointer);
        stack[stackPointer++] = item;
    }
    template push(T)
    {
        void push(T x)
        {
            this.push(new Atom(x));
        }
    }

    // Debugging information about itself:
    override string toString()
    {
        string s = "Process[" ~ to!string(this.index) ~ "]";
        s ~= "(" ~ program.name ~ "):\n";

        s ~= "STACK:" ~ to!string(stack[0..stackPointer]) ~ "\n";
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

        /*
        name: std.math.run
        Prefix: std.math
        Let's try to autoimport!
        */
        bool success = {
            string modulePath = to!string(name.split(".")[0..$-1].join("."));

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

            return false;
        }();

        if (success) {
            // We imported the module, but we're not sure if this
            // name actually exists inside it:
            // (Important: do NOT call this method recursively!)
            handler = this.program.commands.get(name, null);
            if (handler is null)
            {
                throw new Exception("Command not found: " ~ name);
            }
        }
        return handler;
    }

    // Execution
    CommandContext run()
    {
        auto context = CommandContext(this);
        // TODO: check if this.program !is null
        return this.run(this.program, context);
    }
    CommandContext run(SubProgram subprogram)
    {
        auto context = CommandContext(this);
        return this.run(subprogram, context);
    }
    CommandContext run(SubProgram subprogram, CommandContext context)
    {
        foreach(pipeline; subprogram.pipelines)
        {
            trace("\nrunning pipeline:", pipeline);
            context = pipeline.run(context);
            trace("  pipeline.context:", context);

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
                    // ReturnSuccess is received here when
                    // we are still INSIDE A PROC.
                    // We return the context, but out caller
                    // doesn't necessarily have to break:
                    context.exitCode = ExitCode.CommandSuccess;
                    return context;

                case ExitCode.Failure:
                    throw new Exception("Failure: " ~ to!string(context));

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
        }

        // Returns the context of the last expression:
        trace("SubProgram.RETURNING ", context);
        trace(" escopo:", this);
        return context;
    }
}
