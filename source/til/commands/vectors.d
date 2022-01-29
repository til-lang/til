module til.commands.vectors;

import til.nodes;
import til.commands;

debug
{
    import std.stdio;
}


static this()
{
    commands["bytes"] = new Command((string path, Context context)
    {
        auto vector = new BytesVector();

        foreach (item; context.items)
        {
            auto i = item.toInt();
            vector.values ~= cast(byte)i;
        }

        return context.push(vector);
    });
    bytesVectorCommands["length"] = new Command((string path, Context context)
    {
        auto vector = context.pop!BytesVector();
        return context.push(vector.values.length);
    });
}
