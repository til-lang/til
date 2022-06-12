module til.commands;

import std.array;
import std.file : read;
import std.path : buildPath;
import std.stdio;
import std.string : toLower, stripRight;

import til.grammar;

import til.conv;
import til.exceptions;
import til.packages;
import til.nodes;
import til.procedures;
import til.process;


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

        string code;
        foreach (fspath; packagesPaths) {
            try
            {
                code = to!string(read(buildPath(fspath, filePath)));
            }
            catch (FileException)
            {
                continue;
            }
        }
        if (code is null)
        {
            auto msg = "Program not found in " ~ filePath;
            return context.error(msg, ErrorCode.NotFound, "");
        }
        auto parser = new Parser(code);
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
    subprogramCommands["run"] = new Command((string path, Context context)
    {
        auto body = context.pop!SubProgram();
        auto escopo = new Escopo(context.escopo);

        auto returnedContext = context.process.run(
            body, context.next(escopo, 0)
        );
        debug {stderr.writeln("returnedContext.size:", returnedContext.size);}
        returnedContext = context.process.closeCMs(returnedContext);
        debug {stderr.writeln("                     ", returnedContext.size);}

        context.size = returnedContext.size;
        if (returnedContext.exitCode == ExitCode.Return)
        {
            // Contain the return chain reaction:
            context.exitCode = ExitCode.Success;
        }
        else
        {
            context.exitCode = returnedContext.exitCode;
        }

        return context;
    });

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
    // Various ExitCodes:
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

    // Scope
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

        auto cmContext = contextManager.runCommand("open", context);

        if (cmContext.exitCode == ExitCode.Failure)
        {
            return cmContext;
        }
        escopo.contextManagers ~= contextManager;

        // Make sure the stack is okay:
        context.items();
        context.push(contextManager);

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
    commands["with"] = new Command((string path, Context context)
    {
        auto target = context.pop();
        auto body = context.pop!SubProgram();

        foreach (pipeline; body.pipelines)
        {
            auto commandCall = pipeline.commandCalls.front;
            commandCall.arguments = [target] ~ commandCall.arguments;
        }

        context = context.process.run(body, context.escopo);

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
