module til.nodes.execlist;

import til.nodes;


class ExecList : BaseList
{
    SubProgram subprogram;

    this(SubProgram subprogram)
    {
        super();
        this.subprogram = subprogram;
        this.type = ObjectType.ExecList;
    }

    override string toString()
    {
        return "[" ~ this.subprogram.toString() ~ "]";
    }
    override Context evaluate(Context context)
    {
        /*
        We must run in a sub-Escopo because of how `on.error`
        procedures are called. Besides, we don't want
        SubProgram names messing up with the caller
        context names, anyway.
        */
        auto escopo = new Process(context.escopo);
        escopo.description = "ExecList.evaluate";
        return escopo.run(this.subprogram, context);
    }

    static ExecList infixProgram(SimpleList source)
    {
        string[] commandNames;
        Items arguments;

        foreach (index, item; source.items)
        {
            // 1 + 2 + 3 + 4 / 5 * 6
            // [+ 1 2]
            // [+ [+ 1 2] 3]
            // [+ [+ [+ 1 2] 3] 4]
            // Alternative:
            // [+ 1 2 3 4]
            // [/ [+ 1 2 3 4] 5]
            // [* [/ [+ 1 2 3 4] 5] 6]
            if (index % 2 == 0)
            {
                if (item.type == ObjectType.SimpleList)
                {
                    // Inner SimpleLists also become InfixPrograms:
                    arguments ~= ExecList.infixProgram(cast(SimpleList)item);
                }
                else
                {
                    arguments ~= item;
                }
            }
            else
            {
                commandNames ~= item.toString();
            }
        }

        string lastCommandName = null;
        auto argumentsIndex = 0;
        auto commandsIndex = 0;
        ExecList execList = null;

        while (argumentsIndex < arguments.length && commandsIndex < commandNames.length)
        {
            Items commandArgs = [arguments[argumentsIndex++]];
            string commandName = commandNames[commandsIndex++];

            while (argumentsIndex < arguments.length)
            {
                commandArgs ~= arguments[argumentsIndex++];
                if (commandsIndex < commandNames.length && commandNames[commandsIndex] == commandName)
                {
                    commandsIndex++;
                    continue;
                }
                else
                {
                    break;
                }
            }
            auto commandCalls = [
                new CommandCall(commandName, commandArgs)
            ];
            auto pipeline = new Pipeline(commandCalls);
            auto subprogram = new SubProgram([pipeline]);
            execList = new ExecList(subprogram);

            // This ExecList replaces the last seen argument:
            arguments[--argumentsIndex] = execList;
            // [0 1 2]
            //      ^
            // [0 [+ 0 1] 2]
            //       ^
        }

        if (execList is null)
        {
            throw new Exception("execList cannot be null!");
        }
        return execList;
    }
}
