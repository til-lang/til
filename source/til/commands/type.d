module til.commands.type;

import til.nodes;
import til.commands;


// Commands:
static this()
{
    nameCommands["type"] = (string path, CommandContext context)
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
}
