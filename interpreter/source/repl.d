module til.interpreter.repl;

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

    process["prompt"] = new String("> ");

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
            break;
        }

        stdout.writeln("[" ~ command ~ "]");
        add_history(command.toStringz());

        process.state = ProcessState.New;
        auto scheduler = new Scheduler(process);
        ExitCode exitCode = scheduler.run();
        command = "";

        foreach (fiber; scheduler.fibers)
        {
            if (fiber.context.exitCode != ExitCode.Proceed)
            {
                stdout.writeln("Process ", fiber.process.index, ":");
                stderr.writeln(" exitCode ", fiber.context.exitCode);
                foreach (item; fiber.context.items)
                {
                    stderr.writeln(" ", item);
                }
            }
            else
            {
                foreach (item; fiber.context.items)
                {
                    stdout.writeln(" ", item);
                }
            }
        }
    }
    clear_history();

    return 0;
}
