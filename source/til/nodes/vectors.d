module til.nodes.vectors;

import std.string : capitalize;

import til.nodes;



class Vector(T) : Item
{
    T[] values;

    auto type = ObjectType.Vector;
    string typeName = T.stringof ~ "_vector";

    this(T[] values)
    {
        this();
        this.values = values;
    }
    this()
    {
        this.commands["length"] = new Command(function(string path, Context context)
        {
            auto item = context.pop!(typeof(this))();
            context.push(item.values.length);
            return context;
        });

        this.commands["extract"] = new Command(function(string path, Context context)
        {
            auto item = context.pop!(typeof(this))();

            auto startItem = context.pop();
            long start = 0;
            if (startItem.toString() == "end")
            {
                start = item.values.length - 1;
                if (start < 0)
                {
                    start = 0;
                }
            }
            else
            {
                start = startItem.toInt();
                if (start < 0)
                {
                    start = item.values.length + start;
                }
            }

            if (context.size == 0)
            {
                return context.push(item.values[start]);
            }

            auto end = start + 1;
            auto endItem = context.pop();
            if (endItem.toString() == "end")
            {
                end = item.values.length;
            }
            else
            {
                end = endItem.toInt();
                if (end < 0)
                {
                    end = item.values.length + end;
                }
            }

            context.exitCode = ExitCode.CommandSuccess;
            Items items;
            foreach (x; item.values[start..end])
            {
                static if (__traits(isFloating, T))
                {
                    items ~= new FloatAtom(x);
                }
                else
                {
                    items ~= new IntegerAtom(x);
                }
            }
            return context.push(new SimpleList(items));
        });
    }
    override string toString()
    {
        return (
            this.typeName ~ ":"
            ~ to!string(
                this.values.map!(x => to!string(x)).join(" ")
            )
        );
    }
}


alias ByteVector = Vector!byte;
alias FloatVector = Vector!float;
alias IntVector = Vector!int;
alias LongVector = Vector!long;
alias DoubleVector = Vector!double;
