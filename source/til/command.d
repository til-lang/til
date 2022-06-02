module til.command;

import std.stdio;

import til.nodes;


alias CommandName = string;
alias CommandHandler = Context function(CommandName, Context);
alias CommandHandlerMap = CommandHandler[string];


class Command
{
    private CommandHandler _handler;
    bool isDeprecated = false;

    this(CommandHandler handler)
    {
        this._handler = handler;
    }

    Context run(CommandName name, Context context)
    {
        if (isDeprecated)
        {
            stderr.writeln("WARNING: the command `" ~ name ~ "` is deprecated");
        }
        context.exitCode = ExitCode.Success;
        auto newContext = this._handler(name, context);
        return newContext;
    }

}
alias CommandsMap = Command[CommandName];
