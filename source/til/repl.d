module til.repl;

import std.stdio;
import std.string : fromStringz, toStringz;

import til.commands;
import til.exceptions;
import til.grammar;
import til.nodes;
import til.scheduler;

import editline;


int repl(Dict envVars, SimpleList argumentsList)
{
    auto process = new Process(null);
    process.description = "repl";
    process["args"] = argumentsList;
    process["env"] = envVars;
    process.commands = commands;
    string command;

    ListItem* promptString = ("TIL_PROMPT" in envVars.values);
    if (promptString !is null)
    {
        process["prompt"] = *promptString;
    }
    else
    {
        process["prompt"] = new String("> ");
    }

mainLoop:
    while (true)
    {
        auto prompt = process["prompt"][0].toString();

        while (true)
        {
            auto line = readline(prompt.toStringz());
            if (line is null)
            {
                break mainLoop;
            }
            command ~= to!string(line.fromStringz()) ~ "\n";
            if (command.length == 0)
            {
                continue;
            }
            auto parser = new Parser(command);
            try
            {
                process.program = parser.consumeSubProgram();
            }
            catch (IncompleteInputException)
            {
                prompt = "... ";
                continue;
            }
            catch (Exception ex)
            {
                stdout.writeln("Exception: ", ex.msg);
                process.program = null;
            }
            break;
        }

        if (command.length > 1)
        {
            add_history(command.toStringz());
        }
        command = "";

        if (process.program is null)
        {
            continue;
        }

        process.state = ProcessState.New;
        auto scheduler = new Scheduler(process);
        ExitCode exitCode = scheduler.run();

        File output = stdin;
        foreach (fiber; scheduler.fibers)
        {
            if (fiber.context.exitCode != ExitCode.Proceed)
            {
                stdout.writeln(fiber.process.fullDescription, ":");
                stderr.writeln(" exitCode ", fiber.context.exitCode);
                output = stderr;
            }
            else
            {
                output = stdout;
            }

            foreach (item; fiber.context.items)
            {
                output.writeln(" ", item);
            }

        }
    }
    clear_history();

    return 0;
}
