module til.commands;

import std.algorithm.iteration : map, joiner;
import std.array;
import std.conv : to;
import std.file : read;
import std.stdio;

import til.grammar;

import til.exceptions;
import til.logic;
import til.modules;
import til.nodes;
import til.process : typesCommands;
import til.procedures;
import til.ranges;
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
    // Modules / includes
    stringCommands["include"] = (string path, CommandContext context)
    {
        import std.stdio;
        import std.file;

        string filePath = context.pop!string;
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
        auto modulePath = context.pop!string;
        string newName = modulePath;

        // import std.io as x
        if (context.size == 2)
        {
            string asWord = context.pop!string;
            debug {stderr.writeln("asWord:", asWord);}
            if (asWord != "as")
            {
                auto msg = "Invalid syntax for import";
                return context.error(msg, ErrorCode.InvalidArgument, "");
            }
            newName = context.pop!string;
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
    // Flow control
    simpleListCommands["if"] = (string path, CommandContext context)
    {
        context = ()
        {
            while(true)
            {
                auto conditions = context.pop!SimpleList;
                auto thenBody = context.pop!SubList;

                debug {stderr.writeln("context before conditions evaluation:", context);}
                conditions.forceEvaluate(context);
                // auto resultContext = boolean(context.next(1));
                context.run(&boolean, 1);

                auto isConditionTrue = context.pop!bool;
                debug {stderr.writeln("context AFTER conditions evaluation:", context);}

                debug {stderr.writeln(conditions, " is ", isConditionTrue);}

                // if (x == 0) {...}
                if (isConditionTrue)
                {
                    return context.escopo.run(thenBody.subprogram);
                }
                // no else:
                else if (context.size == 0)
                {
                    context.exitCode = ExitCode.CommandSuccess;
                    return context;
                }
                // else {...}
                // else if {...}
                else
                {
                    auto elseWord = context.pop!string;
                    if (elseWord != "else")
                    {
                        auto msg = "Invalid format for if/then/else clause:"
                                   ~ " elseWord found was " ~ elseWord;
                        return context.error(msg, ErrorCode.InvalidSyntax, "");
                    }

                    debug {stderr.writeln("context:", context);}

                    // If only one part is left, it's for sure the last "else":
                    if (context.size == 1)
                    {
                        auto elseBody = context.pop!SubList;
                        return context.escopo.run(elseBody.subprogram);
                    }
                    else
                    {
                        auto ifWord = context.pop!string;
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
        }();
        if (context.exitCode == ExitCode.Proceed)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        return context;
    };

    nameCommands["foreach"] = (string path, CommandContext context)
    {
        auto argName = context.pop!string;
        auto argBody = context.pop!SubList;

        /*
        Do NOT create a new scope for the
        body of foreach.
        */
        auto loopScope = context.escopo;

        uint yieldStep;
        if (argBody.subprogram.pipelines.length >= 8)
        {
            yieldStep = 0x01;
        }
        else if (argBody.subprogram.pipelines.length >= 4)
        {
            yieldStep = 0x03;
        }
        else
        {
            yieldStep = 0x07;
        }

        uint index = 0;
        debug {stderr.writeln("foreach context.stream: ", context.stream);}

        auto stream = context.stream;
        foreach(item; stream)
        {
            debug {stderr.writeln("foreach item: ", item);}
            loopScope[argName] = item;

            context = loopScope.run(argBody.subprogram);
            debug {stderr.writeln("foreach.subprogram.exitCode:", context.exitCode);}

            if (context.exitCode == ExitCode.Break)
            {
                /*
                We pop the front because we assume
                the loop scope already did
                whatever it was going to
                do with the value.
                */
                stream.popFront();
                break;
            }
            else if (context.exitCode == ExitCode.Continue)
            {
                continue;
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
                debug {stderr.writeln("foreach yieldStep");}
                context.yield();
            }
        }

        /*
        `foreach` is NOT a "sink", because you can simply
        break the loop "in the middle" of a stream and
        the rest can be passed to other command to
        process.
        */
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
    // "switch/case"
    commands["transform"] = (string path, CommandContext context)
    {
        class TransformRange : InfiniteRange
        {
            Range origin;
            SubList body;
            Process escopo;
            string varName;
            this(Range origin, string varName, SubList body, Process escopo)
            {
                this.origin = origin;
                this.varName = varName;
                this.body = body;
                this.escopo = escopo;
            }

            override bool empty()
            {
                return origin.empty;
            }
            override ListItem front()
            {
                auto originalFront = origin.front;
                escopo[varName] = originalFront;
                context = escopo.run(body.subprogram);
                if (context.size > 1)
                {
                    return new SimpleList(context.items);
                }
                else
                {
                    return context.pop();
                }
            }
            override void popFront()
            {
                origin.popFront();
            }
        }

        auto varName = context.pop!string;
        auto body = context.pop!SubList;

        auto newStream = new TransformRange(context.stream, varName, body, context.escopo);
        context.exitCode = ExitCode.CommandSuccess;
        context.stream = newStream;
        return context;
    };
    simpleListCommands["case"] = (string path, CommandContext context)
    {
        /*
        | case (>name "txt") {
            print "$name is a plain text file"
        } case (>name "md") {
            print "$name is a MarkDown file"
        }
        */
        auto stream = context.stream;

        // Put a "case" string just to be coherent with
        // subsequent ones:
        context.push("case");

        // Collect all "cases":
        struct caseCondition
        {
            Items variables;
            SubList body;
        }
        caseCondition[] caseConditions;

        while(context.size)
        {
            auto caseWord = context.pop!string;
            if (caseWord != "case")
            {
                auto msg = "Malformed `case` command: " ~ caseWord;
                return context.error(msg, ErrorCode.InvalidSyntax, "");
            }
            auto argNames = context.pop!SimpleList;
            caseConditions ~= caseCondition(
                argNames.items, context.pop!SubList
            );
        }

        foreach (streamItem; stream)
        {
            debug {
                stderr.writeln(
                    "case streamItem:", streamItem.type, "/", streamItem,
                    "/", typeid(streamItem)
                );
            }

            Items currentItems;
            if (streamItem.type == ObjectType.List)
            {
                // currentItems = streamItem.items;
                auto list = cast(SimpleList)streamItem;
                if (list !is null)
                {
                    currentItems = list.items;
                }
                else
                {
                    throw new Exception(
                        "Cannot cast "
                        ~ to!string(typeid(streamItem))
                        ~ " to SimpleList"
                    );
                }
            }
            else
            {
                debug {stderr.writeln(streamItem.type, " != ", ObjectType.List); }
                currentItems = [streamItem];
            }
            debug {stderr.writeln("currentItems:", currentItems);}

            foreach (condition; caseConditions)
            {
                int matched = 0;
                foreach(index, item; currentItems)
                {
                    debug {stderr.writeln("case item:", item.type, "/", item);}
                    // case (>name, "txt")
                    auto variable = condition.variables[index];
                    debug {
                        stderr.writeln(
                            "case variable:", variable.type, "/", variable
                        );
                    }
                    if (variable.type == ObjectType.InputName)
                    {
                        // Assignment
                        context.escopo[to!string(variable)] = item;
                        matched++;
                    }
                    else
                    {
                        // Comparison
                        ListItem result = variable.operate("==", item, false);
                        if (result.toBool == true)
                        {
                            matched++;
                        }
                        else
                        {
                            break;
                        }
                    }
                }

                if (matched == condition.variables.length)
                {
                    context = context.escopo.run(condition.body.subprogram);
                    switch(context.exitCode)
                    {
                        case ExitCode.Break:
                            context.exitCode = ExitCode.CommandSuccess;
                            return context;
                        case ExitCode.ReturnSuccess:
                            return context;
                        default:
                            break;
                    }
                    break;
                }
            }
        }

        if (context.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        return context;
    };

    // ---------------------------------------------
    // Procedures-related
    nameCommands["proc"] = (string path, CommandContext context)
    {
        // proc name (parameters) {body}

        string name = context.pop!(string);
        auto parameters = context.pop!SimpleList;
        auto body = context.pop!SubList;

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
        auto newContext = context.next;
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
        // spawn f | foreach x { ... }
        // range 5 | spawn g | foreach y { ... }

        auto commandName = context.pop!string;
        Items arguments = context.items;

        auto command = new Command(commandName, arguments);
        auto pipeline = new Pipeline([command]);
        auto subprogram = new SubProgram([pipeline]);
        auto process = new Process(context.escopo, subprogram);

        // Piping:
        if (context.stream is null)
        {
            process.input = new ProcessIORange(context.escopo, commandName ~ ":in");
            debug {writeln("process.input: ", context.escopo);}
        }
        else
        {
            process.input = context.stream;
        }
        // Important: it's not the current process, but the new one, here:
        process.output = new ProcessIORange(process, commandName ~ ":out");

        auto pid = context.escopo.scheduler.add(process);

        context.push(pid);

        // Piping out:
        context.stream = process.output;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Printing:
    commands["print"] = (string path, CommandContext context)
    {
        while(context.size > 1) stdout.write(context.pop!string, " ");
        stdout.write(context.pop!string);
        stdout.writeln();

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["print.error"] = (string path, CommandContext context)
    {
        while(context.size > 1) stderr.write(context.pop!string, " ");
        stderr.write(context.pop!string);
        stderr.writeln();

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Piping
    commands["read"] = (string path, CommandContext context)
    {
        context.stream = context.escopo.input;
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    commands["write"] = (string path, CommandContext context)
    {
        if (context.size > 1)
        {
            auto msg = "`write` expect only one argument";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        context.escopo.output.write(context.pop());
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    // ---------------------------------------------
    // Errors
    commands["error"] = (string path, CommandContext context)
    {
        string classe = "";
        int code = -1;
        // TODO: improve default message:
        string message = "An error ocurred";

        // "Full" call:
        // error message code class
        // error "Not Found" 404 http
        // error "segmentation fault" 11 os
        if (context.size > 0)
        {
            message = context.pop!string;
        }
        if (context.size > 0)
        {
            code = cast(int)context.pop!long;
        }
        if (context.size > 0)
        {
            classe = context.pop!string;
        }

        return context.error(message, code, classe);
    };

    // ---------------------------------------
    // Dict:
    commands["dict"] = (string path, CommandContext context)
    {
        auto dict = new Dict();

        foreach(argument; context.items)
        {
            SimpleList l = cast(SimpleList)argument;
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
            size = context.pop!ulong;
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
    implement each builtin type here.

    "Built-in type" == anything that the parser is able to instantiate
    */

    // ---------------------------------------------
    // Atoms:
    // XXX: `incr` and `decr` do NOT conform to Tcl "equivalents"!
    integerCommands["incr"] = (string path, CommandContext context)
    {
        // TODO: check parameters count
        auto integer = context.pop!IntegerAtom;

        // TODO: check for overflow
        integer.value++;
        context.push(integer);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    integerCommands["decr"] = (string path, CommandContext context)
    {
        // TODO: check parameters count
        auto integer = context.pop!IntegerAtom;

        // TODO: check for underflow
        integer.value--;
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
        auto start = context.pop!long;
        long limit = 0;
        if (context.size)
        {
            limit = context.pop!long;
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
            step = context.pop!long;
        }

        class IntegerRange : InfiniteRange
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

            override void popFront()
            {
                current += step;
            }
            override ListItem front()
            {
                return new IntegerAtom(current);
            }
            override bool empty()
            {
                return (current > limit);
            }
        }

        auto range = new IntegerRange(start, limit, step);
        context.stream = range;
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // Names:
    nameCommands["set"] = (string path, CommandContext context)
    {
        string[] names;

        if (context.size < 2)
        {
            auto msg = "`name.set` must receive at least two arguments.";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }

        auto key = context.pop!string;
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

        auto l1 = context.pop!SimpleList;
        auto l2 = context.pop!SimpleList;

        debug {stderr.write("l1, l2: ", l1, " , ", l2);}

        // TODO : it seem right, but we should test
        // if the cast won't change the type or
        // anything like that (I believe it
        // makes no sense, actually,
        // but...)
        if (l2.type != ObjectType.List)
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
    simpleListCommands["eval"] = (string path, CommandContext context)
    {
        // Expect a SimpleList:
        auto list = context.pop();

        // Force evaluation:
        auto newContext = list.evaluate(context, true);

        newContext.exitCode = ExitCode.CommandSuccess;
        return newContext;
    };
    simpleListCommands["range"] = (string path, CommandContext context)
    {
        /*
        range (1 2 3 4 5)
        */
        class ItemsRange : Range
        {
            Items list;
            int currentIndex = 0;
            ulong _length;

            this(Items list)
            {
                this.list = list;
                this._length = list.length;
            }

            override bool empty()
            {
                return (this.currentIndex >= this._length);
            }
            override ListItem front()
            {
                return this.list[this.currentIndex];
            }
            override void popFront()
            {
                this.currentIndex++;
            }
        }

        SimpleList list = context.pop!SimpleList;
        context.stream = new ItemsRange(list.items);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    simpleListCommands["math"] = (string path, CommandContext context)
    {
        import til.math;

        auto list = cast(SimpleList)context.pop();
        context.run(&list.forceEvaluate);

        auto newContext = int_run(context);
        if (newContext.size != 1)
        {
            auto msg = "math.run: error. Should return 1 item.\n"
                       ~ to!string(newContext.escopo)
                       ~ " returned " ~ to!string(newContext.size);
            return context.error(msg, ErrorCode.InternalError, "til.internal");
        }

        // int_run pushes a new list, but we don't want that.
        auto resultList = cast(SimpleList)context.pop();
        foreach(item; resultList.items)
        {
            context.push(item);
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    // Pids:
    pidCommands["send"] = (string path, CommandContext context)
    {
        if (context.size > 2)
        {
            auto msg = "`send` expect only two arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "");
        }
        Pid pid = cast(Pid)context.pop();
        auto value = context.pop();

        // If we *have* the Pid, the input *is* a ProcessIORange.
        auto input = cast(ProcessIORange)pid.process.input;
        input.write(value);

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    // Dicts:
    dictCommands["set"] = (string path, CommandContext context)
    {
        auto dict = context.pop!Dict;

        foreach(argument; context.items)
        {
            SimpleList l = cast(SimpleList)argument;
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
        auto dict = context.pop!Dict;

        foreach (argument; context.items)
        {
            string key;
            if (argument.type == ObjectType.List)
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

    // ---------------------------------------
    // Queues:
    queueCommands["push"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue;

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
        auto queue = context.pop!Queue;

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
        auto queue = context.pop!Queue;
        long howMany = 1;
        if (context.size > 0)
        {
            auto integer = context.pop!IntegerAtom;
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
        auto queue = context.pop!Queue;
        long howMany = 1;
        if (context.size > 0)
        {
            auto integer = context.pop!IntegerAtom;
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
        auto queue = context.pop!Queue;

        foreach (item; context.stream)
        {
            while (queue.isFull)
            {
                context.yield();
            }
            queue.push(item);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["send.no_wait"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue;

        foreach (item; context.stream)
        {
            if (queue.isFull)
            {
                auto msg = "queue is full";
                return context.error(msg, ErrorCode.Full, "");
            }
            queue.push(item);
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["receive"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue;
        context.stream = new WaitQueueRange(queue, context);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };
    queueCommands["receive.no_wait"] = (string path, CommandContext context)
    {
        auto queue = context.pop!Queue;
        context.stream = new NoWaitQueueRange(queue, context);
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------
    // Shared libraries:
    til.sharedlibs.loadCommands(commands);

    // Types commands:
    typesCommands["integer"] = integerCommands;
    typesCommands["name"] = nameCommands;
    typesCommands["string"] = stringCommands;
    typesCommands["list"] = simpleListCommands;
    typesCommands["pid"] = pidCommands;
    typesCommands["dict"] = dictCommands;
    typesCommands["queue"] = queueCommands;
}
