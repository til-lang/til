module til.commands;

import std.algorithm.iteration : joiner, map;
import std.algorithm.searching : canFind;
import std.algorithm.sorting : sort;
import std.array;
import std.conv : to, ConvException;
import std.file : read;
import std.regex : matchAll;
import std.stdio;
import std.string : indexOf, toLower;

import til.grammar;

import til.conv;
import til.exceptions;
import til.exec;
import til.math;
import til.modules;
import til.nodes;
import til.procedures;
import til.sharedlibs;


CommandHandlerMap commands;


SubProgram parse(string code)
{
    auto parser = new Parser(code);
    return parser.run();
}


// Commands:
static this()
{
    // ---------------------------------------------
    // Stack
    commands["push"] = (string path, CommandContext context)
    {
        // Do nothing, the value is already on stack.
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["pop"] = (string path, CommandContext context)
    {
        context.size++;
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["stack"] = (string path, CommandContext context)
    {
        context.size = cast(int)context.escopo.stackPointer;
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Modules / includes
    stringCommands["include"] = (string path, CommandContext context)
    {
        import std.stdio;
        import std.file;

        string filePath = context.pop!string();
        debug {stderr.writeln("include.filePath:", filePath);}

        auto program = parse(to!string(read(filePath)));
        if (program is null)
        {
            auto msg = "Program in " ~ filePath ~ " is invalid";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }

        context = context.escopo.run(program, context);

        if (context.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        return context;
    };
    nameCommands["import"] = (string path, CommandContext context)
    {
        // import std.io as x
        auto modulePath = context.pop!string();
        string newName = modulePath;

        // import std.io as x
        if (context.size == 2)
        {
            string asWord = context.pop!string();
            if (asWord != "as")
            {
                auto msg = "Invalid syntax for import";
                return context.error(msg, ErrorCode.InvalidArgument, "");
            }
            newName = context.pop!string();
        }

        if (!context.escopo.importModule(modulePath, newName))
        {
            auto msg = "Module not found: " ~ modulePath;
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Strings commands
    stringCommands["extract"] = (string path, CommandContext context)
    {
        String s = context.pop!String();

        if (context.size == 0) return context.push(s);

        auto start = context.pop().toInt();
        if (start < 0)
        {
            start = s.repr.length + start;
        }

        auto end = start + 1;
        if (context.size)
        {
            end = context.pop().toInt();
            if (end < 0)
            {
                end = s.repr.length + end;
            }
        }

        context.exitCode = ExitCode.CommandSuccess;
        context.push(new String(s.repr[start..end]));
        return context;
    };
    stringCommands["eval"] = (string path, CommandContext context)
    {
        import til.grammar;

        auto code = context.pop!string();

        auto parser = new Parser(code);
        SubProgram subprogram = parser.run();

        context = context.escopo.run(subprogram);
        if (context.exitCode == ExitCode.Proceed)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        return context;
    };
    stringCommands["length"] = (string path, CommandContext context)
    {
        auto s = context.pop!String();
        context.exitCode = ExitCode.CommandSuccess;
        return context.push(s.repr.length);
    };
    stringCommands["split"] = (string path, CommandContext context)
    {
        auto s = context.pop!string;
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` expects two arguments";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        auto separator = context.pop!string;

        SimpleList l = new SimpleList(
            cast(Items)(s.split(separator)
                .map!(x => new String(x))
                .array)
        );

        context.push(l);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    stringCommands["join"] = (string path, CommandContext context)
    {
        string joiner = context.pop!string();
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` expects at least two arguments";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        foreach (item; context.items)
        {
            if (item.type != ObjectType.SimpleList)
            {
                auto msg = "`" ~ path ~ "` expects a list of SimpleLists";
                return context.error(msg, ErrorCode.InvalidSyntax, "");
            }
            SimpleList l = cast(SimpleList)item;
            context.push(
                new String(l.items.map!(x => to!string(x)).join(joiner))
            );
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    stringCommands["find"] = (string path, CommandContext context)
    {
        string needle = context.pop!string();
        // TODO: make the following code template:
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` expects two arguments";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        foreach(item; context.items)
        {
            string haystack = item.toString();
            context.push(haystack.indexOf(needle));
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    stringCommands["matches"] = (string path, CommandContext context)
    {
        string expression = context.pop!string();
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` expects two arguments";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        string target = context.pop!string();

        SimpleList l = new SimpleList([]);
        foreach(m; target.matchAll(expression))
        {
            l.items ~= new String(m.hit);
        }
        context.push(l);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    stringCommands["range"] = (string path, CommandContext context)
    {
        /*
        range "12345" -> 1 , 2 , 3 , 4 , 5
        */
        class StringRange : Item
        {
            string s;
            int currentIndex = 0;
            ulong _length;

            this(string s)
            {
                this.s = s;
                this._length = s.length;
            }
            override string toString()
            {
                return "StringRange";
            }
            override CommandContext next(CommandContext context)
            {
                if (this.currentIndex >= this._length)
                {
                    context.exitCode = ExitCode.Break;
                }
                else
                {
                    auto chr = this.s[this.currentIndex++];
                    context.push(to!string(chr));
                    context.exitCode = ExitCode.Continue;
                }
                return context;
            }
        }

        string s = context.pop!string();
        context.push(new StringRange(s));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // System commands
    commands["exec"] = (string path, CommandContext context)
    {
        string[] command;
        ListItem inputStream;

        if (context.hasInput)
        {
            command = context.pop(context.size - 1).map!(x => to!string(x)).array;
            inputStream = context.pop();
        }
        else
        {
            command = context.items.map!(x => to!string(x)).array;
        }

        context.push(new SystemProcess(command, inputStream));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Native types, nodes and conversion
    commands["typeof"] = (string path, CommandContext context)
    {
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` expects one argument";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        Item target = context.pop();
        context.push(new NameAtom(to!string(target.type).toLower()));

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    stringCommands["to.int"] = (string path, CommandContext context)
    {
        string target = context.pop!string();

        auto result = toLong(target);
        if (!result.success)
        {
            auto msg = "Could not convert to integer";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        context.push(result.value);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    stringCommands["to.float"] = (string path, CommandContext context)
    {
        string target = context.pop!string();

        if (target.length == 0)
        {
            target = "0.0";
        }

        float result;
        try
        {
            result = to!float(target);
        }
        catch (ConvException)
        {
            auto msg = "Could not convert to float";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        context.push(result);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["to.string"] = (string path, CommandContext context)
    {
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` expects at least one argument";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        foreach(item; context.items.retro)
        {
            context.push(item.toString());
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Flow control
    simpleListCommands["if"] = (string path, CommandContext context)
    {
        while(true)
        {
            // NOT popping the conditions: `math` will take care of that, already.
            auto mathContext = math(context.next(1));
            auto isConditionTrue = mathContext.pop!bool();

            auto thenBody = context.pop!SubList();

            if (isConditionTrue)
            {
                // Get rid of eventual "else":
                context.items();
                // Run body:
                context = context.escopo.run(thenBody.subprogram);
                break;
            }
            // no else:
            else if (context.size == 0)
            {
                context.exitCode = ExitCode.CommandSuccess;
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
                    auto elseBody = context.pop!SubList();
                    context = context.escopo.run(elseBody.subprogram);
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

        if (context.exitCode == ExitCode.Proceed)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        return context;
    };

    nameCommands["foreach"] = (string path, CommandContext context)
    {
        /*
        range 5 | foreach x { ... }
        */
        if (context.size < 2)
        {
            auto msg = "`foreach` expects two arguments";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }

        auto argName = context.pop!string();
        auto argBody = context.pop!SubList();

        /*
        Do NOT create a new scope for the
        body of foreach.
        */
        auto loopScope = context.escopo;

        uint yieldStep = 0x07;

        uint index = 0;
        auto target = context.pop();

        // Remember: `context` is going to change a lot from now on.
        auto nextContext = context;
forLoop:
        while (true)
        {
            nextContext = target.next(context.next());
            switch (nextContext.exitCode)
            {
                case ExitCode.Break:
                    break forLoop;
                case ExitCode.Failure:
                    return nextContext;
                case ExitCode.Skip:
                    continue;
                case ExitCode.Continue:
                    break;
                default:
                    return nextContext;
            }

            loopScope[argName] = nextContext.items;

            context = loopScope.run(argBody.subprogram);

            if (context.exitCode == ExitCode.Break)
            {
                break;
            }
            else if (context.exitCode == ExitCode.ReturnSuccess)
            {
                // Return should always return
                // until a procedure or
                // a program is
                // stopped:
                return context;
            }

            if ((index++ & yieldStep) == yieldStep)
            {
                context.yield();
            }
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["break"] = (string path, CommandContext context)
    {
        context.exitCode = ExitCode.Break;
        return context;
    };
    commands["continue"] = (string path, CommandContext context)
    {
        context.exitCode = ExitCode.Continue;
        return context;
    };

    // ---------------------------------------------
    commands["transform"] = (string path, CommandContext context)
    {
        class Transformer : Item
        {
            Item target;
            SubList body;
            Process escopo;
            string varName;
            bool empty;

            this(Item target, string varName, SubList body, Process escopo)
            {
                this.target = target;
                this.varName = varName;
                this.body = body;
                this.escopo = escopo;
            }

            override string toString()
            {
                return "transform";
            }

            override CommandContext next(CommandContext context)
            {
                auto targetContext = this.target.next(context);
                switch (targetContext.exitCode)
                {
                    case ExitCode.Break:
                    case ExitCode.Failure:
                    case ExitCode.Skip:
                        return targetContext;
                    case ExitCode.Continue:
                        break;
                    default:
                        throw new Exception(
                            to!string(this.target)
                            ~ ".next returned "
                            ~ to!string(targetContext.exitCode)
                        );
                }

                escopo[varName] = targetContext.items;

                context = escopo.run(body.subprogram);

                switch(context.exitCode)
                {
                    case ExitCode.ReturnSuccess:
                    case ExitCode.CommandSuccess:
                    case ExitCode.Proceed:
                        context.exitCode = ExitCode.Continue;
                        break;

                    default:
                        break;
                }
                return context;
            }
        }

        if (context.size < 2)
        {
            auto msg = "`transform` expects two arguments";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        auto varName = context.pop!string();
        auto body = context.pop!SubList();

        if (context.size == 0)
        {
            auto msg = "no target to transform";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        auto target = context.pop();

        auto iterator = new Transformer(
            target, varName, body, context.escopo
        );
        context.push(iterator);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Procedures-related
    nameCommands["proc"] = (string path, CommandContext context)
    {
        // proc name (parameters) {body}

        if (context.size != 3)
        {
            auto msg = "`proc` expects three arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        string name = context.pop!string();
        auto parameters = context.pop!SimpleList();
        auto body = context.pop!SubList();

        auto proc = new Procedure(
            name,
            parameters,
            body
        );

        CommandContext closure(string path, CommandContext context)
        {
            return proc.run(path, context);
        }

        // Make the procedure available:
        context.escopo.commands[name] = &closure;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["return"] = (string path, CommandContext context)
    {
        context.exitCode = ExitCode.ReturnSuccess;
        return context;
    };
    commands["skip"] = (string path, CommandContext context)
    {
        context.exitCode = ExitCode.Skip;
        return context;
    };

    commands["scope"] = (string path, CommandContext context)
    {
        string name = context.pop!string();
        SubList body = context.pop!SubList();

        auto process = new Process(context.escopo);
        process.description = name;
        process.variables = context.escopo.variables;

        auto returnedContext = process.run(body.subprogram, context.next(process, 0));

        if (returnedContext.exitCode == ExitCode.Proceed)
        {
            returnedContext.exitCode = ExitCode.CommandSuccess;
        }

        Items managers = process.internalVariables.require("cm", []);
        foreach (contextManager; managers)
        {
            returnedContext = contextManager.runCommand(returnedContext, "close");
        }

        return returnedContext;
    };
    commands["with"] = (string path, CommandContext context)
    {
        // with cm [context_manager 1 2 3]
        string name = context.pop!string();
        auto contextManager = context.pop();

        auto process = context.escopo;

        process[name] = contextManager;
        context = contextManager.runCommand(context, "open");

        Items managers = process.internalVariables.require("cm", []);
        managers ~= contextManager;
        process.internalVariables["cm"] = managers;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Scope manipulation
    commands["uplevel"] = (string path, CommandContext context)
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

        // 1- create a new Command
        auto command = new Command(cmdName, cmdArguments);

        // 2- create a new context, with the parent
        //    scope as the context.escopo
        auto newContext = context.next();
        newContext.escopo = parentScope;
        newContext.size = context.size;

        // 3- run the command
        auto returnedContext = command.run(newContext);

        if (returnedContext.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        return context;
    };

    // ---------------------------------------------
    // Scheduler-related:
    nameCommands["spawn"] = (string path, CommandContext context)
    {
        // set pid [spawn f $x]
        // spawn f | read | foreach x { ... }
        // range 5 | spawn g | foreach y { ... }

        auto commandName = context.pop!string();
        Items arguments = context.items;
        ListItem input = null;
        if (context.hasInput)
        {
            input = arguments[$-1];
            arguments.popBack();
        }

        auto command = new Command(commandName, arguments);
        auto pipeline = new Pipeline([command]);
        auto subprogram = new SubProgram([pipeline]);
        auto process = new Process(context.escopo, subprogram);
        process.description = commandName;

        // Piping:
        if (input !is null)
        {
            // receive $queue | spawn some_procedure
            process.input = input;
        }
        else
        {
            process.input = new WaitingQueue(64);
        }
        process.output = new WaitingQueue(64);

        auto pid = context.escopo.scheduler.add(process);
        context.push(pid);

        // Give some time for the new process to start:
        context.yield();

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Printing:
    commands["print"] = (string path, CommandContext context)
    {
        while(context.size) stdout.write(context.pop!string());
        stdout.writeln();

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["print.error"] = (string path, CommandContext context)
    {
        while(context.size) stderr.write(context.pop!string());
        stderr.writeln();

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Piping
    commands["read"] = (string path, CommandContext context)
    {
        if (context.escopo.input is null)
        {
            auto msg = "`read.no_wait`: process input is null";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        // Probably a WaitingQueue:
        context.push(context.escopo.input);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["read.no_wait"] = (string path, CommandContext context)
    {
        if (context.escopo.input is null)
        {
            auto msg = "`read.no_wait`: process input is null";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        // Probably a WaitingQueue, let's change its behavior to
        // a regular Queue:
        auto q = cast(WaitingQueue)context.escopo.input;
        context.push(new Queue(q));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["write"] = (string path, CommandContext context)
    {
        if (context.size > 1)
        {
            auto msg = "`write` expects only one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        Queue output = cast(Queue)context.escopo.output;
        output.push(context.pop());

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    // ---------------------------------------------
    // Time
    commands["sleep"] = (string path, CommandContext context)
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
            else
            {
                context.yield();
            }
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    // ---------------------------------------------
    // Errors
    commands["error"] = (string path, CommandContext context)
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
    };

    // ---------------------------------------------
    // Debugging
    commands["assert"] = (string path, CommandContext context)
    {
        while (context.size)
        {
            auto target = context.peek();
            auto mathContext = math(context.next(1));
            auto isTrue = mathContext.pop!bool();
            if (!isTrue)
            {
                auto msg = "assertion error: " ~ target.toString();
                return context.error(msg, ErrorCode.Assertion, "");
            }
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    // Dict:
    commands["dict"] = (string path, CommandContext context)
    {
        auto dict = new Dict();

        foreach(argument; context.items)
        {
            SimpleList l = cast(SimpleList)argument;
            context = l.forceEvaluate(context);
            l = cast(SimpleList)context.pop();

            ListItem value = l.items.back;
            l.items.popBack();
            string key = to!string(l.items.map!(x => to!string(x)).join("."));
            dict[key] = value;
        }
        context.push(dict);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    // Queue:
    commands["queue"] = (string path, CommandContext context)
    {
        ulong size = 64;
        if (context.size > 0)
        {
            size = context.pop!ulong();
        }
        auto queue = new Queue(size);

        context.push(queue);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    /*
    We can't really use module constructors inside
    til.nodes.* because then your're triggering
    cyclic dependencies all around, so we
    implement each builtin type methods here.
    */

    // ---------------------------------------------
    // Atoms:
    // (Please notice: `incr` and `decr` do NOT conform to Tcl "equivalents"!)
    integerCommands["incr"] = (string path, CommandContext context)
    {
        if (context.size != 1)
        {
            auto msg = "`incr` expects one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto integer = context.pop!IntegerAtom();

        if (integer.value > ++integer.value)
        {
            auto msg = "integer overflow";
            return context.error(msg, ErrorCode.Overflow, "");
        }
        context.push(integer);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    integerCommands["decr"] = (string path, CommandContext context)
    {
        if (context.size != 1)
        {
            auto msg = "`decr` expects one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto integer = context.pop!IntegerAtom();
        if (integer.value < --integer.value)
        {
            auto msg = "integer underflow";
            return context.error(msg, ErrorCode.Underflow, "");
        }
        context.push(integer);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    integerCommands["range"] = (string path, CommandContext context)
    {
        /*
           range 10       # [zero, 10]
           range 10 20    # [10, 20]
           range 10 14 2  # 10 12 14
        */
        auto start = context.pop!long();
        long limit = 0;
        if (context.size)
        {
            limit = context.pop!long();
        }
        else
        {
            // zero to...
            limit = start;
            start = 0;
        }
        if (limit <= start)
        {
            auto msg = "Invalid range";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        long step = 1;
        if (context.size)
        {
            step = context.pop!long();
        }

        class IntegerRange : Item
        {
            long start = 0;
            long limit = 0;
            long step = 1;
            long current = 0;

            this(long limit)
            {
                this.limit = limit;
            }
            this(long start, long limit)
            {
                this(limit);
                this.current = start;
                this.start = start;
            }
            this(long start, long limit, long step)
            {
                this(start, limit);
                this.step = step;
            }

            override string toString()
            {
                return
                    "range("
                    ~ to!string(start)
                    ~ ","
                    ~ to!string(limit)
                    ~ ")";
            }

            override CommandContext next(CommandContext context)
            {
                long value = current;
                if (value > limit)
                {
                    context.exitCode = ExitCode.Break;
                }
                else
                {
                    context.push(value);
                    context.exitCode = ExitCode.Continue;
                }
                current += step;
                return context;
            }
        }

        auto range = new IntegerRange(start, limit, step);
        context.push(range);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    integerCommands["exit"] = (string path, CommandContext context)
    {
        string classe = "";
        string message = "Process was stopped";

        IntegerAtom code = cast(IntegerAtom)context.pop();

        if (context.size > 0)
        {
            message = context.pop!string();
        }

        return context.error(message, cast(int)code.value, classe);
    };
    integerCommands["operate"] = (string path, CommandContext context)
    {
        IntegerAtom t2 = context.pop!IntegerAtom();
        Item operator = context.pop();
        Item lhs = context.pop();

        string op = to!string(operator);

        if (lhs.type != ObjectType.Integer)
        {
            context.push(t2);
            context.push(operator);
            return lhs.reverseOperate(context);
        }

        auto t1 = cast(IntegerAtom)lhs;
        final switch(op)
        {
            // Logic:
            case "==":
                context.push(t1.value == t2.value);
                break;
            case "!=":
                context.push(t1.value != t2.value);
                break;
            case ">":
                context.push(t1.value > t2.value);
                break;
            case ">=":
                context.push(t1.value >= t2.value);
                break;
            case "<":
                context.push(t1.value < t2.value);
                break;
            case "<=":
                context.push(t1.value <= t2.value);
                break;

            // Math:
            case "+":
                context.push(t1.value + t2.value);
                break;
            case "-":
                context.push(t1.value - t2.value);
                break;
            case "*":
                context.push(t1.value * t2.value);
                break;
            case "/":
                context.push(t1.value / t2.value);
                break;
            case "%":
                context.push(t1.value % t2.value);
                break;
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // Names:
    commands["set"] = (string path, CommandContext context)
    {
        string[] names;

        if (context.size < 2)
        {
            auto msg = "`name.set` must receive at least two arguments.";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto key = context.pop!string();
        context.escopo[key] = context.items;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    nameCommands["unset"] = (string path, CommandContext context)
    {
        string[] names;

        auto firstArgument = context.pop();

        context.escopo.variables.remove(to!string(firstArgument));

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    nameCommands["operate"] = (string path, CommandContext context)
    {
        Item rhs = context.pop();
        Item operator = context.pop();
        Item lhs = context.pop();

        switch(to!string(operator))
        {
            case "==":
                context.push(to!string(lhs) == to!string(rhs));
                break;
            case "!=":
                context.push(to!string(lhs) != to!string(rhs));
                break;
            default:
                context.push(rhs);
                context.push(operator);
                return lhs.reverseOperate(context);
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    // SimpleLists:
    commands["list"] = (string path, CommandContext context)
    {
        /*
        set l [list 1 2 3 4]
        # l = (1 2 3 4)
        */
        context.exitCode = ExitCode.CommandSuccess;
        return context.push(new SimpleList(context.items));
    };
    simpleListCommands["set"] = (string path, CommandContext context)
    {
        string[] names;

        if (context.size != 2)
        {
            auto msg = "`list.set` must receive two arguments.";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto l1 = context.pop!SimpleList();
        auto l2 = context.pop!SimpleList();

        if (l2.type != ObjectType.SimpleList)
        {
            auto msg = "You can only use `list.set` with two SimpleLists";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        names = l1.items.map!(x => to!string(x)).array;

        Items values;
        context = l2.forceEvaluate(context);
        values = l2.items;

        if (values.length < names.length)
        {
            auto msg = "Insuficient number of items in the second list";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        string lastName;
        foreach(name; names)
        {
            auto nextValue = values.front;
            if (!values.empty) values.popFront();

            context.escopo[name] = nextValue;
            lastName = name;
        }
        while(!values.empty)
        {
            // Everything else goes to the last name:
            context.escopo[lastName] = context.escopo[lastName] ~ values.front;
            values.popFront();
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["range"] = (string path, CommandContext context)
    {
        /*
        range (1 2 3 4 5)
        */
        class ItemsRange : Item
        {
            Items list;
            int currentIndex = 0;
            ulong _length;

            this(Items list)
            {
                this.list = list;
                this._length = list.length;
            }
            override string toString()
            {
                return "ItemsRange";
            }
            override CommandContext next(CommandContext context)
            {
                if (this.currentIndex >= this._length)
                {
                    context.exitCode = ExitCode.Break;
                }
                else
                {
                    auto item = this.list[this.currentIndex++];
                    context.push(item);
                    context.exitCode = ExitCode.Continue;
                }
                return context;
            }
        }

        SimpleList list = context.pop!SimpleList();
        context.push(new ItemsRange(list.items));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["range.enumerate"] = (string path, CommandContext context)
    {
        /*
        range.enumerate (1 2 3 4 5)
        -> 0 1 , 1 2 , 2 3 , 3 4 , 4 5
        */
        // TODO: make ItemsRange from "range" accessible here.
        class ItemsRangeEnumerate : Item
        {
            Items list;
            int currentIndex = 0;
            ulong _length;

            this(Items list)
            {
                this.list = list;
                this._length = list.length;
            }
            override string toString()
            {
                return "ItemsRangeEnumerate";
            }
            override CommandContext next(CommandContext context)
            {
                if (this.currentIndex >= this._length)
                {
                    context.exitCode = ExitCode.Break;
                }
                else
                {
                    auto item = this.list[this.currentIndex];
                    context.push(item);
                    context.push(currentIndex);
                    this.currentIndex++;
                    context.exitCode = ExitCode.Continue;
                }
                return context;
            }
        }

        SimpleList list = context.pop!SimpleList();
        context.push(new ItemsRangeEnumerate(list.items));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["math"] = (string path, CommandContext context)
    {
        // NOT popping the SimpleList: `math` will handle that, already:
        context = math(context.next(1));
        if (context.size != 1)
        {
            auto msg = "math.run: error. Should return 1 item.\n"
                       ~ to!string(context.escopo)
                       ~ " returned " ~ to!string(context.size);
            return context.error(msg, ErrorCode.InternalError, "til.internal");
        }

        // NOT pushing the result: `math` already did that.
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    simpleListCommands["extract"] = (string path, CommandContext context)
    {
        SimpleList l = context.pop!SimpleList();

        if (context.size == 0) return context.push(l);

        // start:
        auto start = context.pop().toInt();

        if (start < 0)
        {
            start = l.items.length + start;
        }

        // end:
        auto end = start + 1;
        if (context.size)
        {
            end = context.pop().toInt();
            if (end < 0)
            {
                end = l.items.length + end;
            }
        }

        // slice:
        context.push(new SimpleList(l.items[start..end]));

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["eval"] = (string path, CommandContext context)
    {
        auto list = context.pop();

        // Force evaluation:
        auto newContext = list.evaluate(context, true);

        newContext.exitCode = ExitCode.CommandSuccess;
        return newContext;
    };
    simpleListCommands["expand"] = (string path, CommandContext context)
    {
        SimpleList list = context.pop!SimpleList();

        foreach (item; list.items.retro)
        {
            context.push(item);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["push"] = (string path, CommandContext context)
    {
        SimpleList list = context.pop!SimpleList();

        Items items = context.items;
        list.items ~= items;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["pop"] = (string path, CommandContext context)
    {
        SimpleList list = context.pop!SimpleList();

        if (list.items.length == 0)
        {
            auto msg = "Cannot pop: the list is empty";
            return context.error(msg, ErrorCode.Empty, "");
        }

        auto lastItem = list.items[$-1];
        context.push(lastItem);
        list.items.popBack;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["sort"] = (string path, CommandContext context)
    {
        SimpleList list = context.pop!SimpleList();

        class Comparator
        {
            ListItem item;
            CommandContext context;
            this(CommandContext context, ListItem item)
            {
                this.context = context;
                this.item = item;
            }

            override int opCmp(Object o)
            {
                Comparator other = cast(Comparator)o;

                context.push(other.item);
                context.push("<");
                context = item.operate(context);
                auto result = cast(BooleanAtom)context.pop();

                if (result.value)
                {
                    return -1;
                }
                else
                {
                    return 0;
                }
            }
        }

        Comparator[] comparators = list.items.map!(x => new Comparator(context, x)).array;
        Items sorted = comparators.sort.map!(x => x.item).array;
        context.push(new SimpleList(sorted));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["reverse"] = (string path, CommandContext context)
    {
        SimpleList list = context.pop!SimpleList();
        Items reversed = list.items.retro.array;
        context.push(new SimpleList(reversed));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["contains"] = (string path, CommandContext context)
    {
        if (context.size != 2)
        {
            auto msg = "`send` expects two arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        SimpleList list = context.pop!SimpleList();
        ListItem item = context.pop();

        context.exitCode = ExitCode.CommandSuccess;
        return context.push(
            list.items
                .map!(x => to!string(x))
                .canFind(to!string(item))
        );
    };
    simpleListCommands["length"] = (string path, CommandContext context)
    {
        auto l = context.pop!SimpleList();
        context.exitCode = ExitCode.CommandSuccess;
        return context.push(l.items.length);
    };

    // ---------------------------------------
    // Sequences
    commands["zip"] = (string path, CommandContext context)
    {

        class Zipper : Item
        {
            Items items;
            this(Items items)
            {
                this.items = items;
            }
            override string toString()
            {
                return "Zipper";
            }
            override CommandContext next(CommandContext context)
            {
                Items iterationItems;
                foreach (item; items.retro)
                {
zipIteration:
                    while (true)
                    {
                        auto itemContext = item.next(context.next());
                        switch (itemContext.exitCode)
                        {
                            case ExitCode.Skip:
                                continue;
                            case ExitCode.Break:
                            case ExitCode.Failure:
                                return itemContext;
                            default:
                                iterationItems ~= itemContext.items;
                                break zipIteration;
                        }
                    }
                }

                context.push(iterationItems);
                context.exitCode = ExitCode.Continue;
                return context;
            }
        }

        context.push(new Zipper(context.items));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    // Pids:
    pidCommands["send"] = (string path, CommandContext context)
    {
        if (context.size > 2)
        {
            auto msg = "`send` expects only two arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        Pid pid = cast(Pid)context.pop();
        auto value = context.pop();

        // Process input should be a Queue:
        Queue input = cast(Queue)pid.process.input;
        input.push(value);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    // Dicts:
    dictCommands["set"] = (string path, CommandContext context)
    {
        auto dict = context.pop!Dict();

        foreach(argument; context.items)
        {
            SimpleList l = cast(SimpleList)argument;
            context = l.forceEvaluate(context);
            l = cast(SimpleList)context.pop();

            ListItem value = l.items.back;
            l.items.popBack();
            string key = to!string(l.items.map!(x => to!string(x)).join("."));
            dict[key] = value;
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    dictCommands["unset"] = (string path, CommandContext context)
    {
        auto dict = context.pop!Dict();

        foreach (argument; context.items)
        {
            string key;
            if (argument.type == ObjectType.SimpleList)
            {
                auto list = cast(SimpleList)argument;
                auto keysContext = list.evaluate(context.next());
                auto evaluatedList = cast(SimpleList)keysContext.pop();
                auto parts = evaluatedList.items;

                key = to!string(
                    parts.map!(x => to!string(x)).join(".")
                );
            }
            else
            {
                key = to!string(argument);
            }
            dict.values.remove(key);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    dictCommands["extract"] = (string path, CommandContext context)
    {
        Dict d = context.pop!Dict();
        auto arguments = context.items!string;
        string key = to!string(arguments.join("."));
        context.push(d[key]);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    // Queues:
    queueCommands["push"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue();

        foreach(argument; context.items)
        {
            while (queue.isFull)
            {
                context.yield();
            }
            queue.push(argument);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["push.no_wait"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue();

        foreach(argument; context.items)
        {
            if (queue.isFull)
            {
                auto msg = "queue is full";
                return context.error(msg, ErrorCode.Full, "");
            }
            queue.push(argument);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["pop"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue();
        long howMany = 1;
        if (context.size > 0)
        {
            auto integer = context.pop!IntegerAtom();
            howMany = integer.value;
        }
        foreach(idx; 0..howMany)
        {
            while (queue.isEmpty)
            {
                context.yield();
            }
            context.push(queue.pop());
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["pop.no_wait"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue();
        long howMany = 1;
        if (context.size > 0)
        {
            auto integer = context.pop!IntegerAtom();
            howMany = integer.value;
        }
        foreach(idx; 0..howMany)
        {
            if (queue.isEmpty)
            {
                auto msg = "queue is empty";
                return context.error(msg, ErrorCode.Empty, "");
            }
            context.push(queue.pop());
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["send"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue();

        if (context.size == 0)
        {
            auto msg = "no target to send from";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        auto target = context.pop();

        auto nextContext = context;
        do
        {
            nextContext = target.next(context);
            if (nextContext.exitCode == ExitCode.Break)
            {
                break;
            }
            auto item = nextContext.pop();

            while (queue.isFull)
            {
                context.yield();
            }
            queue.push(item);
        }
        while(nextContext.exitCode != ExitCode.Break);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["send.no_wait"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue();

        if (context.size == 0)
        {
            auto msg = "no target to send from";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        auto target = context.pop();

        auto nextContext = context;
        do
        {
            nextContext = target.next(context);
            if (nextContext.exitCode == ExitCode.Break)
            {
                break;
            }
            auto item = nextContext.pop();
            if (queue.isFull)
            {
                auto msg = "queue is full";
                return context.error(msg, ErrorCode.Full, "");
            }
            queue.push(item);
        }
        while(nextContext.exitCode != ExitCode.Break);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["receive"] = (string path, CommandContext context)
    {
        if (context.size != 1)
        {
            auto msg = "`receive` expects one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        class QueueIterator : Item
        {
            Queue queue;
            this(Queue queue)
            {
                this.queue = queue;
            }
            override string toString()
            {
                return "QueueIterator";
            }
            override CommandContext next(CommandContext context)
            {
                while (queue.isEmpty)
                {
                    context.yield();
                }
                auto item = queue.pop();
                context.push(item);
                context.exitCode = ExitCode.Continue;
                return context;
            }
        }

        auto queue = context.pop!Queue();
        context.push(new QueueIterator(queue));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["receive.no_wait"] = (string path, CommandContext context)
    {
        if (context.size != 1)
        {
            auto msg = "`receive` expects one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        class QueueIteratorNoWait : Item
        {
            Queue queue;
            this(Queue queue)
            {
                this.queue = queue;
            }
            override string toString()
            {
                return "QueueIteratorNoWait";
            }
            override CommandContext next(CommandContext context)
            {
                if (queue.isEmpty)
                {
                    context.exitCode = ExitCode.Break;
                }
                else
                {
                    context.exitCode = ExitCode.Continue;
                    auto item = queue.pop();
                    context.push(item);
                }
                return context;
            }
        }

        auto queue = context.pop!Queue();
        context.push(new QueueIteratorNoWait(queue));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Custom types
    commands["type"] = (string path, CommandContext context)
    {
        /*
        type coordinates {
            proc init (x y) {
                return [dict (x $x) (y $y)
            }
        }
        */
        auto name = context.pop!string();
        auto sublist = context.pop();

        auto subprogram = (cast(SubList)sublist).subprogram;
        auto newScope = new Process(context.escopo);
        newScope.description = name;
        auto newContext = context.next(newScope, context.size);

        // RUN!
        newContext = newContext.escopo.run(subprogram, newContext);

        if (newContext.exitCode == ExitCode.Failure)
        {
            // Simply pop up the error:
            return newContext;
        }
        else
        {
            newContext.exitCode = ExitCode.CommandSuccess;
        }

        auto type = new Type(name);
        type.commands = newScope.commands;
        CommandHandler* initMethod = ("init" in newScope.commands);
        if (initMethod is null)
        {
            auto msg = "The type " ~ name ~ " must have a `init` method";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }

        context.escopo.commands[name] = (string path, CommandContext context)
        {
            auto returnContext = (*initMethod)(path, context);
            if (returnContext.exitCode == ExitCode.Failure)
            {
                return returnContext;
            }

            CommandHandlerMap newCommands;

            auto returnedObject = returnContext.pop();

            string prefix1 = returnedObject.typeName ~ ".";

            // global "to.string" -> dict.to.string
            // do it here because these names CAN be
            // freely overwritten.
            foreach(cmdName, command; commands)
            {
                string newName = prefix1 ~ cmdName;
                newCommands[newName] = command;
            }

            // coordinates : dict
            //  set -> set (from dict)
            //  set -> dict.set
            // returnedObject is a `dict`
            // 
            // position : coordinates
            // set -> (coordinates)set
            // set -> coordinates.set
            // dict.set -> dict.set
            // dict.set -> coordinates.dict.set
            // returnedObject is a `coordinates`
            //
            foreach(cmdName, command; returnedObject.commands)
            {
                newCommands[cmdName] = command;
                newCommands[prefix1 ~ cmdName] = command;
                // newCommands[prefix2 ~ cmdName] = command;
            }

            // set (from coordinates) -> set (simple copy)
            foreach(cmdName, command; type.commands)
            {
                newCommands[cmdName] = command;
            }
            returnedObject.commands = newCommands;
            returnedObject.typeName = name;

            returnContext.push(returnedObject);
            return returnContext;
        };

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    // Shared libraries:
    til.sharedlibs.loadCommands(commands);
}
