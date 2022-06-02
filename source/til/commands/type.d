module til.commands.type;

import til.commands;
import til.procedures;
import til.nodes;


class TypeCommand : Command
{
    string name;
    CommandsMap commands;
    CommandsMap[string] newCommandsCache;

    this(string name, Escopo escopo)
    {
        this.name = name;
        this.commands = escopo.commands;
        super(null);
    }
    override string toString()
    {
        return "type:" ~ this.name;
    }

    override Context run(string path, Context context)
    {
        debug {stderr.writeln("Type.run:", path); }

        auto init = this.commands["init"];
        auto initContext = init.run("init", context.next(context.size));
        debug {stderr.writeln(" init.exitCode:", initContext.exitCode); }

        if (initContext.exitCode == ExitCode.Failure)
        {
            return initContext;
        }

        auto returnedObject = initContext.pop();
        debug {stderr.writeln(" returnedObject:", returnedObject); }

        returnedObject.commands = resolveCommands(returnedObject);
        returnedObject.typeName = this.name;

        return context.push(returnedObject);
    };

    CommandsMap resolveCommands(Item returnedObject)
    {
        auto cacheEntryPtr = (returnedObject.typeName in newCommandsCache);
        if (cacheEntryPtr is null)
        {
            auto newCommands = doResolveCommands(returnedObject);
            newCommandsCache[returnedObject.typeName] = newCommands;
            return newCommands;
        }
        else
        {
            return *cacheEntryPtr;
        }
    }

    CommandsMap doResolveCommands(Item returnedObject)
    {
        CommandsMap newCommands;

        string prefix1 = returnedObject.typeName ~ ".";

        // global "to.string" -> dict.to.string
        // do it here because these names CAN be
        // freely overwritten.
        foreach(cmdName, command; til.commands.commands)
        {
            string newName = prefix1 ~ cmdName;
            debug {stderr.writeln(" global:", newName); }
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
            string newName = prefix1 ~ cmdName;
            newCommands[newName] = command;
            newCommands[cmdName] = command;
            debug {stderr.writeln(" ", returnedObject.typeName, ":", newName);}
        }

        // set (from coordinates) -> set (simple copy)
        foreach(cmdName, command; this.commands)
        {
            newCommands[cmdName] = command;
            debug {stderr.writeln(" ", this.name, ":", cmdName);}
        }

        return newCommands;
    }
}


// Commands:
static this()
{
    nameCommands["type"] = new Command((string path, Context context)
    {
        auto name = context.pop!string();
        auto subprogram = context.pop!SubProgram();

        auto newScope = new Escopo(context.escopo);
        newScope.description = name;
        auto newContext = context.next(newScope, context.size);

        // RUN!
        newContext = newContext.process.run(subprogram, newContext);

        if (newContext.exitCode == ExitCode.Failure)
        {
            // Simply pop up the error:
            return newContext;
        }

        // Quick sanity check:
        Command* initMethod = ("init" in newScope.commands);
        if (initMethod is null)
        {
            auto msg = "The type " ~ name ~ " must have an `init` method";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        context.escopo.commands[name] = new TypeCommand(name, newScope);

        return context;
    });
}
