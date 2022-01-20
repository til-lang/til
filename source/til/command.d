module til.command;

import til.nodes;


alias CommandName = string;
alias CommandHandler = Context function(CommandName, Context);
alias CommandHandlerMap = CommandHandler[string];

class Command
{
    private CommandHandler _handler;
    private Runnable _runnable;

    this(CommandHandler handler)
    {
        this(handler, null);
    }
    this(CommandHandler handler, Runnable runnable)
    {
        this._handler = handler;
        this._runnable = runnable;
    }

    @property
    Runnable runnable()
    {
        return this._runnable;
    }

    Context run(CommandName name, Context context)
    {
        context.exitCode = ExitCode.CommandSuccess;
        context.command = this;
        auto newContext = this._handler(name, context);
        return newContext;
    }

}
alias CommandsMap = Command[CommandName];
