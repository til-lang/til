module til.commands;

import std.array;
import std.file : read;
import std.stdio;
import std.string : toLower, stripRight;

import til.grammar;

import til.conv;
import til.exceptions;
import til.packages;
import til.nodes;
import til.procedures;
import til.process;
// import til.sharedlibs;


// Global variable:
CommandsMap commands;


// Commands:
static this()
{
    // ---------------------------------------------
    // Stack
    commands["stack.push"] = new Command((string path, Context context)
    {
        // Do nothing, the value is already on stack.
        return context;
    });

    commands["stack.pop"] = new Command((string path, Context context)
    {
        if (context.process.stack.stackPointer == 0)
        {
            auto msg = "Stack is empty";
            return context.error(msg, ErrorCode.SemanticError, "");
        }

        long quantity = 1;
        if (context.size) {
            quantity = context.pop!long();
        }
        context.size += quantity;
        return context;
    });

    commands["stack"] = new Command((string path, Context context)
    {
        context.size = cast(int)context.process.stack.stackPointer;
        return context;
    });

    // ---------------------------------------------
    // Modules / includes
    stringCommands["include"] = new Command((string path, Context context)
    {
        import std.stdio;
        import std.file;

        string filePath = context.pop!string();
        debug {stderr.writeln("include.filePath:", filePath);}

        auto parser = new Parser(to!string(read(filePath)));
        auto program = parser.run();
        if (program is null)
        {
            auto msg = "Program in " ~ filePath ~ " is invalid";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }

        context = context.process.run(program, context);

        // XXX: maybe this is wrong.
        // What if I want to include a code that returns Continue?
        if (context.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.Success;
        }
        return context;
    });
    nameCommands["import"] = new Command((string path, Context context)
    {
        // import std.io
        auto packagePath = context.pop!string();
        string newName = packagePath;

        // import std.io x
        if (context.size)
        {
            newName = context.pop!string();
        }

        if (!context.escopo.importModule(packagePath, newName))
        {
            auto msg = "Module not found: " ~ packagePath;
            return context.error(msg, ErrorCode.NotFound, "");
        }

        return context;
    });

    // ---------------------------------------------
    stringCommands["eval"] = new Command((string path, Context context)
    {
        import til.grammar;

        auto code = context.pop!string();

        auto parser = new Parser(code);
        SubProgram subprogram = parser.run();

        context = context.process.run(subprogram, context.next());
        return context;
    });

    // ---------------------------------------------
    // Native types, nodes and conversion
    commands["typeof"] = new Command((string path, Context context)
    {
        Item target = context.pop();
        context.push(new NameAtom(to!string(target.type).toLower()));

        return context;
    });
    commands["type.name"] = new Command((string path, Context context)
    {
        Item target = context.pop();
        context.push(new NameAtom(to!string(target.typeName).toLower()));

        return context;
    });
    commands["to.string"] = new Command((string path, Context context)
    {
        foreach(item; context.items.retro)
        {
            context.push(item.toString());
        }

        return context;
    });
    commands["to.bool"] = new Command((string path, Context context)
    {
        auto target = context.pop();
        return context.push(target.toBool());
    });
    commands["to.int"] = new Command((string path, Context context)
    {
        auto target = context.pop();
        return context.push(target.toInt());
    });
    commands["to.float"] = new Command((string path, Context context)
    {
        auto target = context.pop();
        return context.push(target.toFloat());
    });


    // ---------------------------------------------
    // Flow control
    commands["if"] = new Command((string path, Context context)
    {
        while(true)
        {
            auto isConditionTrue = context.pop!bool();
            auto thenBody = context.pop!SubProgram();

            if (isConditionTrue)
            {
                // Get rid of eventual "else":
                context.items();
                // Run body:
                context = context.process.run(thenBody, context.next());
                break;
            }
            // no else:
            else if (context.size == 0)
            {
                context.exitCode = ExitCode.Success;
                break;
            }
            // else {...}
            // else if {...}
            else
            {
                auto elseWord = context.pop!string();
                if (elseWord != "else")
                {
                    auto msg = "Invalid format for if/then/else clause:"
                               ~ " elseWord found was " ~ elseWord  ~ ".";
                    return context.error(msg, ErrorCode.InvalidSyntax, "");
                }

                // If only one part is left, it's for sure the last "else":
                if (context.size == 1)
                {
                    auto elseBody = context.pop!SubProgram();
                    context = context.process.run(elseBody, context.next());
                    break;
                }
                else
                {
                    auto ifWord = context.pop!string();
                    if (ifWord != "if")
                    {
                        auto msg = "Invalid format for if/then/else clause"
                                   ~ " ifWord found was " ~ ifWord;
                        return context.error(msg, ErrorCode.InvalidSyntax, "");
                    }
                    // The next item is an "if", so we can
                    // simply return to the beginning:
                    continue;
                }
            }
        }

        return context;
    });
    nameCommands["foreach"] = new Command((string path, Context context)
    {
        /*
        range 5 | foreach x { ... }
        */
        auto argName = context.pop!string();
        auto argBody = context.pop!SubProgram();

        /*
        Do NOT create a new scope for the
        body of foreach.
        */
        auto loopScope = context.escopo;

        uint index = 0;

        foreach (target; context.items)
        {
            debug {stderr.writeln("foreach.target:", target);}
    forLoop:
            while (true)
            {
                auto nextContext = target.next(context.next());
                debug {stderr.writeln("foreach next.exitCode:", nextContext.exitCode);}
                switch (nextContext.exitCode)
                {
                    case ExitCode.Break:
                        break forLoop;
                    case ExitCode.Failure:
                        return nextContext;
                    case ExitCode.Skip:
                        continue;
                    case ExitCode.Continue:
                        break;  // <-- break the switch, not the while.
                    default:
                        return nextContext;
                }

                loopScope[argName] = nextContext.items;

                context = context.process.run(argBody, context.next());
                debug {stderr.writeln("foreach context.exitCode:", context.exitCode);}

                if (context.exitCode == ExitCode.Break)
                {
                    break;
                }
                else if (context.exitCode == ExitCode.Return)
                {
                    /*
                    Return propagates up into the
                    processes stack:
                    */
                    return context;
                }
                else if (context.exitCode == ExitCode.Failure)
                {
                    return context;
                }
            }
        }

        context.exitCode = ExitCode.Success;
        return context;
    });
    commands["transform"] = new Command((string path, Context context)
    {
        class Transformer : Item
        {
            Items targets;
            size_t targetIndex = 0;
            SubProgram body;
            Context context;
            string varName;
            bool empty;

            this(
                Items targets,
                string varName,
                SubProgram body,
                Context context
            )
            {
                this.targets = targets;
                this.varName = varName;
                this.body = body;
                this.context = context;
            }

            override string toString()
            {
                return "transform";
            }

            override Context next(Context context)
            {
                auto target = targets[targetIndex];
                auto targetContext = target.next(context);

                switch (targetContext.exitCode)
                {
                    case ExitCode.Break:
                        targetIndex++;
                        if (targetIndex < targets.length)
                        {
                            return next(context);
                        }
                        goto case;
                    case ExitCode.Failure:
                    case ExitCode.Skip:
                        return targetContext;
                    case ExitCode.Continue:
                        break;
                    default:
                        throw new Exception(
                            to!string(target)
                            ~ ".next returned "
                            ~ to!string(targetContext.exitCode)
                        );
                }

                context.escopo[varName] = targetContext.items;

                auto execContext = context.process.run(body, context);

                switch(execContext.exitCode)
                {
                    case ExitCode.Return:
                    case ExitCode.Success:
                        execContext.exitCode = ExitCode.Continue;
                        break;

                    default:
                        break;
                }
                return execContext;
            }
        }

        auto varName = context.pop!string();
        auto body = context.pop!SubProgram();

        if (context.size == 0)
        {
            auto msg = "no target to transform";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        auto targets = context.items;

        auto iterator = new Transformer(
            targets, varName, body, context
        );
        context.push(iterator);
        return context;
    });
    commands["collect"] = new Command((string path, Context context)
    {
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` needs at least one input stream";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }

        Items items;

        foreach (input; context.items)
        {
            while (true)
            {
                auto nextContext = input.next(context.next());
                if (nextContext.exitCode == ExitCode.Break)
                {
                    break;
                }
                else if (nextContext.exitCode == ExitCode.Skip)
                {
                    continue;
                }
                else if (nextContext.exitCode == ExitCode.Failure)
                {
                    return nextContext;
                }
                auto x = nextContext.items;
                items ~= x;
            }
        }

        return context.push(new SimpleList(items));
    });
    commands["break"] = new Command((string path, Context context)
    {
        context.exitCode = ExitCode.Break;
        return context;
    });
    commands["continue"] = new Command((string path, Context context)
    {
        context.exitCode = ExitCode.Continue;
        return context;
    });
    commands["skip"] = new Command((string path, Context context)
    {
        context.exitCode = ExitCode.Skip;
        return context;
    });

    // ---------------------------------------------
    // Procedures-related
    nameCommands["alias"] = new Command((string path, Context context)
    {
        string origin = context.pop!string();
        string target = context.pop!string();

        auto command = context.escopo.getCommand(origin);
        if (command is null)
        {
            auto msg = "Command `" ~ origin ~ "` not found";
            return context.error(msg, ErrorCode.CommandNotFound, "");
        }
        commands[target] = command;
        return context;
    });
    nameCommands["proc"] = new Command((string path, Context context)
    {
        // proc name (parameters) {body}
        string name = context.pop!string();

        string[] parameters = context.pop!SimpleList()
            .items
            .map!(x => x.toString())
            .array;
        auto body = context.pop!SubProgram();

        auto proc = new Procedure(
            name,
            parameters,
            body
        );

        context.escopo.commands[name] = proc;

        return context;
    });
    stringCommands["proc"] = nameCommands["proc"];

    commands["return"] = new Command((string path, Context context)
    {
        context.exitCode = ExitCode.Return;
        return context;
    });
    commands["scope"] = new Command((string path, Context context)
    {
        string name = context.pop!string();
        SubProgram body = context.pop!SubProgram();

        auto escopo = new Escopo(context.escopo, name);
        escopo.variables = context.escopo.variables;

        auto returnedContext = context.process.run(
            body, context.next(escopo, 0)
        );
        returnedContext = context.process.closeCMs(returnedContext);

        context.size = returnedContext.size;
        context.exitCode = returnedContext.exitCode;
        return context;
    });

    commands["autoclose"] = new Command((string path, Context context)
    {
        // context_manager 1 2 3 | autoclose | as cm
        auto contextManager = context.peek();
        auto escopo = context.escopo;

        context = contextManager.runCommand("open", context);

        if (context.exitCode == ExitCode.Failure)
        {
            return context;
        }

        escopo.contextManagers ~= contextManager;

        context.exitCode = ExitCode.Success;
        return context;
    });

    commands["uplevel"] = new Command((string path, Context context)
    {
        /*
        uplevel set parent_value x
        */
        auto parentScope = context.escopo.parent;
        if (parentScope is null)
        {
            auto msg = "No upper level to access.";
            return context.error(msg, ErrorCode.SemanticError, "");
        }

        /*
        It is very important to do this `pop` **before**
        copying the context.size into
        newContext.size!
        You see,
        uplevel set x 1 2 3  ← this command has 5 arguments
           -    set x 1 2 3  ← and this one has 4
        */
        auto cmdName = context.pop!(string);

        /*
        Also important to remember: `uplevel` is a command itself.
        As such, all its arguments were already evaluated
        when it was called, so we can safely assume
        there's no further  substitutions to be
        made and this is going to apply to
        the command we are calling
        */
        auto cmdArguments = context.items;

        // 1- create a new CommandCall
        auto command = new CommandCall(cmdName, cmdArguments);

        // 2- create a new context, with the parent
        //    scope as the context.escopo
        auto newContext = context.next();
        newContext.escopo = parentScope;
        newContext.size = context.size;

        // 3- run the command
        auto returnedContext = command.run(newContext);

        if (returnedContext.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.Success;
        }
        return context;
    });


    // ---------------------------------------------
    // Text I/O:
    commands["print"] = new Command((string path, Context context)
    {
        while(context.size) stdout.write(context.pop!string());
        stdout.writeln();
        return context;
    });
    commands["print.error"] = new Command((string path, Context context)
    {
        while(context.size) stderr.write(context.pop!string());
        stderr.writeln();
        return context;
    });

    commands["read"] = new Command((string path, Context context)
    {
        // read a line from std.stdin
        return context.push(new String(stdin.readln().stripRight("\n")));
    });

    // ---------------------------------------------
    // Time
    integerCommands["sleep"] = new Command((string path, Context context)
    {
        import std.datetime.stopwatch;

        auto ms = context.pop!long();

        auto sw = StopWatch(AutoStart.yes);
        while(true)
        {
            auto passed = sw.peek.total!"msecs";
            if (passed >= ms)
            {
                break;
            }
        }
        return context;
    });
    // ---------------------------------------------
    // Errors
    commands["error"] = new Command((string path, Context context)
    {
        string classe = "";
        int code = -1;
        string message = "An error ocurred";

        // "Full" call:
        // error message code class
        // error "Not Found" 404 http
        // error "segmentation fault" 11 os
        if (context.size > 0)
        {
            message = context.pop!string();
        }
        if (context.size > 0)
        {
            code = cast(int)context.pop!long();
        }
        if (context.size > 0)
        {
            classe = context.pop!string();
        }

        return context.error(message, code, classe);
    });

    // ---------------------------------------------
    // Debugging
    commands["assert"] = new Command((string path, Context context)
    {
        foreach (item; context.items)
        {
            if (!item.toBool())
            {
                auto msg = "assertion error: " ~ item.toString();
                return context.error(msg, ErrorCode.Assertion, "");
            }
        }
        return context;
    });

    /*
    We can't really use module constructors inside
    til.nodes.* because then your're triggering
    cyclic dependencies all around, so we
    implement each builtin type methods here.
    */

    // ---------------------------------------------
    commands["exit"] = new Command((string path, Context context)
    {
        string classe = "";
        string message = "Process was stopped";

        long code = 0;

        if (context.size)
        {
            code = context.pop!long();
        }

        if (context.size > 0)
        {
            message = context.pop!string();
        }

        if (code == 0)
        {
            context.exitCode = ExitCode.Return;
            return context;
        }
        else
        {
            return context.error(message, cast(int)code, classe);
        }
    });

    // Names:
    commands["set"] = new Command((string path, Context context)
    {
        if (context.size < 2)
        {
            auto msg = "`" ~ path ~ "` must receive at least two arguments.";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto key = context.pop!string();
        context.escopo[key] = context.items;

        return context;
    });
    commands["as"] = commands["set"];

    nameCommands["unset"] = new Command((string path, Context context)
    {
        auto firstArgument = context.pop();
        context.escopo.variables.remove(to!string(firstArgument));
        return context;
    });

    // ---------------------------------------
    // Information about escopo/process
    commands["cmds"] = new Command((string path, Context context)
    {
        auto process = context.escopo;
        auto cmdsList = new SimpleList([]);

        do
        {
            auto list = new SimpleList([]);
            foreach (cmdName; process.commands.byKey)
            {
                list.items ~= new String(cmdName);
            }
            cmdsList.items ~= list;

            process = process.parent;
        }
        while (process !is null);

        return context.push(cmdsList);
    });
    commands["vars"] = new Command((string path, Context context)
    {
        auto process = context.escopo;
        auto varsList = new SimpleList([]);

        do
        {
            auto list = new SimpleList([]);
            foreach (varName; process.variables.byKey)
            {
                list.items ~= new String(varName);
            }
            varsList.items ~= list;

            process = process.parent;
        }
        while (process !is null);

        return context.push(varsList);
    });
}
