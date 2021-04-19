module til.commands;

import std.algorithm.iteration : map, joiner;
import std.array;
import std.conv : to;
import std.experimental.logger : trace, error;

import til.exceptions;
import til.logic;
import til.modules;
import til.nodes;
import til.procedures;
import til.ranges;


CommandHandler[string] commands;


// Commands:
static this()
{
    // ---------------------------------------------
    // Variables
    commands["set"] = (string path, CommandContext context)
    {
        string[] names;

        if (context.size < 2)
        {
            throw new Exception("`set` must receive at least two arguments.");
        }

        auto firstArgument = context.pop();
        auto secondArgument = context.pop();

        if (firstArgument.type == ObjectTypes.List)
        {
            if (secondArgument.type != ObjectTypes.List)
            {
                throw new Exception(
                    "You can only use destructuring `set` with two SimpleLists"
                );
            }

            auto l1 = cast(SimpleList)firstArgument;
            names = l1.items.map!(x => x.asString).array;

            trace(" names:", names);

            Items values;

            auto l2 = cast(SimpleList)secondArgument;
            context = l2.forceEvaluate(context);
            auto l3 = cast(SimpleList)context.pop();
            values = l3.items;

            trace(" values:", values);

            if (values.length < names.length)
            {
                throw new Exception(
                    "Insuficient number of items in the second list"
                );
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
        }
        else
        {
            context.escopo[firstArgument.asString] = secondArgument;
        }

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Modules / includes
    commands["include"] = (string path, CommandContext context)
    {
        import til.grammar;
        import til.semantics;

        import std.stdio;
        import std.file;

        string filePath = context.pop().asString;
        auto f = File(filePath, "r");
        string code = "";
        foreach(line; f.byLine)
        {
            code ~= line ~ "\n";
        }
        trace("INCLUDED CODE:\n", code);

        auto tree = Til(code);
        trace("TREE:\n", tree);
        auto program = analyse(tree);
        trace("INCLUDE.program:", program);

        context = context.escopo.run(program, context);
        if (context.exitCode != ExitCode.Failure)
        {
            context.exitCode = ExitCode.CommandSuccess;
        }
        return context;
    };

    commands["import"] = (string path, CommandContext context)
    {
        // import std.io as x
        auto modulePath = context.pop().asString;
        string newName = modulePath;

        // import std.io as x
        if (context.size == 2)
        {
            auto as = context.pop().asString;
            if (as != "as")
            {
                throw new InvalidException(
                    "Invalid syntax for import"
                );
            }
            newName = context.pop().asString;
        }
        trace("IMPORT ", modulePath, " AS ", newName);
        context.escopo.program.importModule(modulePath, newName);

        // import std.io as io
        // "io.out" = command
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Flow control
    commands["if"] = (string path, CommandContext context)
    {
        trace("Running command if");
        trace(" inside process ", context.escopo);
        BaseList conditions = cast(BaseList)context.pop();
        ListItem thenBody = context.pop();
        trace("if ", conditions, " then ", thenBody);

        ListItem elseBody;
        // if (condition) {then} else {else}
        if (context.size == 2)
        {
            auto elseWord = context.pop().asString;
            if (elseWord != "else")
            {
                throw new InvalidException(
                    "Invalid format for if/then/else clause"
                );
            }
            elseBody = context.pop();
            trace("   else ", elseBody);
        }
        else
        {
            elseBody = null;
        }

        // Run the condition:
        auto c = cast(SimpleList)conditions;
        context.run(&c.forceEvaluate);
        context.run(&boolean, 1);
        trace(context.escopo);
        auto isConditionTrue = context.pop().asBoolean;

        if (isConditionTrue)
        {
            context = context.escopo.run((cast(SubList)thenBody).subprogram);
        }
        else if (elseBody !is null)
        {
            context = context.escopo.run((cast(SubList)elseBody).subprogram);
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    commands["foreach"] = (string path, CommandContext context)
    {
        trace("foreach.context: ", context);
        auto argName = context.pop().asString;
        auto argBody = cast(SubList)context.pop();

        trace(" FOREACH ", argName, " : ", argBody);

        /*
        Do NOT create a new scope for the
        body of foreach.
        */
        auto loopScope = context.escopo;

        foreach(item; context.stream)
        {
            trace(" item: ", item, " ", item.type);
            loopScope[argName] = item;

            trace("loopScope: ", loopScope);
            context = loopScope.run(argBody.subprogram);

            if (context.exitCode == ExitCode.Break)
            {
                break;
            }
            else if (context.exitCode == ExitCode.Continue)
            {
                continue;
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
            override ulong length()
            {
                return origin.length;
            }
            override Range save()
            {
                return new TransformRange(origin.save(), varName, body, escopo);
            }
            override string toString()
            {
                return "TransformRange";
            }
            override string asString()
            {
                return "TransformRange";
            }
        }

        auto varName = context.pop().asString;
        auto body = context.pop();  // SubList

        auto newStream = new TransformRange(context.stream, varName, cast(SubList)body, context.escopo);
        context.exitCode = ExitCode.CommandSuccess;
        context.stream = newStream;
        return context;
    };
    commands["case"] = (string path, CommandContext context)
    {
        /*
        | case (>name "txt") { io.out "$name is a plain text file" }
        */
        class CaseRange : InfiniteRange
        {
            Range origin;
            SubList body;
            Process escopo;
            Items variables;
            ListItem currentFront;

            this(Range origin, Items variables, SubList body, Process escopo)
            {
                this.origin = origin;
                this.variables = variables;
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
                trace("originalFront:", originalFront);

                SimpleList list;
                if (originalFront.type == ObjectTypes.List)
                {
                    list = cast(SimpleList)originalFront;
                }
                else
                {
                    list = new SimpleList([originalFront]);
                }

                int matched = 0;
                foreach(index, item; list.items)
                {
                    // case (>name, "txt")
                    auto variable = variables[index];
                    trace(variable, " versus ", item, " ", item.type);
                    if (variable.type == ObjectTypes.InputName)
                    {
                        // Assignment
                        escopo[variable.asString] = item;
                        matched++;
                    }
                    else
                    {
                        // Comparison
                        string value = variable.asString;
                        if (value == item.asString)
                        {
                            matched++;
                        }
                        else
                        {
                            break;
                        }
                    }
                }

                if (matched == variables.length)
                {
                    trace(" itMatches: ", list.items, " = ", variables, " | ", escopo);
                    context = escopo.run(body.subprogram);
                    if (context.exitCode == ExitCode.Break)
                    {
                        // An empty SimpleList won't match with anything:
                        return new SimpleList([]);
                    }
                }
                else
                {
                    trace(" not a match: ", list.items, " and ", variables);
                }
                return originalFront;
            }


            override void popFront()
            {
                origin.popFront();
            }
            override ulong length()
            {
                return origin.length;
            }
            override Range save()
            {
                return new CaseRange(origin.save(), variables, body, escopo);
            }
            override string toString()
            {
                return "CaseRange";
            }
            override string asString()
            {
                return "CaseRange";
            }
        }

        auto argNames = cast(SimpleList)context.pop();
        auto variables = argNames.items;
        auto body = cast(SubList)context.pop();

        auto newStream = new CaseRange(context.stream, variables, body, context.escopo);
        context.stream = newStream;

        context.exitCode = ExitCode.CommandSuccess;
        return context;
    };

    // ---------------------------------------------
    // Procedures-related
    commands["proc"] = (string path, CommandContext context)
    {
        // proc name (parameters) {body}

        string name = context.pop().asString;
        ListItem parameters = context.pop();
        ListItem body = context.pop();

        auto proc = new Procedure(
            name,
            parameters,
            // TODO: check if it is really a SubList type:
            body
        );

        CommandContext closure(string path, CommandContext context)
        {
            return proc.run(path, context);
        }

        // Make the procedure available:
        context.escopo.program.commands[name] = &closure;

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
        */
        auto parentScope = context.escopo.parent;
        if (parentScope is null)
        {
            throw new Exception("No upper level to access.");
        }

        /*
        It is very important to do this `pop` **before**
        copying the context.size into
        newContext.size!
        You see,
        uplevel set x 1 2 3  ← this command has 5 arguments
           -    set x 1 2 3  ← and this one has 4
        */
        auto cmdName = context.pop().asString;

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
        /*
        IMPORTANT: always remember the previous (parent) scope
        has an outdated stack that is NOT synchronized
        with the current one. So we need to let
        Command.run "evaluate" all arguments
        again (remember: we passed them
        as a simple Items list), so
        that they end up in the
        old stack as it
        is expected.
        */

        auto returnedContext = command.run(newContext);

        if (returnedContext.exitCode == ExitCode.Failure)
        {
            throw new Exception("upleval/command " ~ cmdName ~ ": Failure");
        }
        context.exitCode = ExitCode.ReturnSuccess;
        return context;
    };
}
