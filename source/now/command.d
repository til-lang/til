module now.command;

import std.stdio;

import now.nodes;


alias CommandName = string;
alias CommandHandler = Context function(CommandName, Context);
alias CommandHandlerMap = CommandHandler[string];


class Command
{
    private CommandHandler _handler;
    bool isDeprecated = false;
    SubProgram[string] eventHandlers;

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

    Context handleEvent(Context context, string event)
    {
        if (auto errorHandlerPtr = ("on.error" in eventHandlers))
        {
            auto errorHandler = *errorHandlerPtr;
            debug {
                stderr.writeln("Calling on.error");
                stderr.writeln(" context:", context);
            }
            /*
            Event handlers are not procedures or
            commands, but simple SubProgram.
            */
            auto newScope = new Escopo(context.escopo);
            // Avoid calling on.error recursively:
            newScope.rootCommand = null;
            auto newContext = Context(context.process, newScope);

            newContext = context.process.run(errorHandler, newContext);
            debug {stderr.writeln(" returned context:", newContext);}
            return newContext;
        }
        else
        {
            return context;
        }
    }
}
alias CommandsMap = Command[CommandName];
