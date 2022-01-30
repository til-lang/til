module til.command;

import til.nodes;


alias CommandName = string;
alias CommandHandler = Context function(CommandName, Context);
alias CommandHandlerMap = CommandHandler[string];


class Command
{
    private CommandHandler _handler;

    this(CommandHandler handler)
    {
        this._handler = handler;
    }

    Context run(CommandName name, Context context)
    {
        context.exitCode = ExitCode.CommandSuccess;
        auto newContext = this._handler(name, context);
        return newContext;
    }

}
alias CommandsMap = Command[CommandName];
