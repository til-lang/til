module til.commands.vectors;

import til.commands;
import til.nodes;


static this ()
{
    void addCommands(T, C)()
    {
        auto typeName = T.stringof ~ "_vector";

        commands[typeName] = new Command((string path, Context context)
        {
            auto vector = new C();

            foreach (item; context.items)
            {
                static if (__traits(isFloating, T))
                {
                    auto x = item.toFloat();
                }
                else
                {
                    auto x = item.toInt();
                }
                vector.values ~= cast(T)x;
            }

            return context.push(vector);
        });
    }

    addCommands!(byte, ByteVector);
    addCommands!(float, FloatVector);
    addCommands!(int, IntVector);
    addCommands!(long, LongVector);
    addCommands!(double, DoubleVector);

    byteVectorCommands["to.string"] = new Command((string path, Context context)
    {
        foreach (item; context.items)
        {
            auto vector = cast(ByteVector)item;
            string s = "";
            foreach (value; vector.values)
            {
                s ~= cast(char)value;
            }
            context.push(s);
        }
        return context;
    });
}
