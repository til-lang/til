module til.commands.string;

import std.array;
import std.conv : ConvException;
import std.regex : matchAll, matchFirst;
import std.string;

import til.conv;
import til.nodes;


// Commands:
static this()
{
    stringCommands["extract"] = new Command((string path, Context context)
    {
        String s = context.pop!String();

        if (context.size == 0) return context.push(s);

        auto start = context.pop().toInt();
        if (start < 0)
        {
            start = s.repr.length + start;
        }

        auto end = start + 1;
        if (context.size)
        {
            auto item = context.pop();
            if (item.toString() == "end")
            {
                end = s.repr.length;
            }
            else
            {
                end = item.toInt();
                if (end < 0)
                {
                    end = s.repr.length + end;
                }
            }
        }

        context.exitCode = ExitCode.CommandSuccess;
        context.push(new String(s.repr[start..end]));
        return context;
    });
    stringCommands["length"] = new Command((string path, Context context)
    {
        foreach (item; context.items)
        {
            auto s = cast(String)item;
            context.push(s.repr.length);
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    stringCommands["split"] = new Command((string path, Context context)
    {
        auto separator = context.pop!string;
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` expects two arguments";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }

        foreach (item; context.items)
        {
            auto s = item.toString();
            SimpleList l = new SimpleList(
                cast(Items)(s.split(separator)
                    .map!(x => new String(x))
                    .array)
            );

            context.push(l);
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    stringCommands["join"] = new Command((string path, Context context)
    {
        string joiner = context.pop!string();
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` expects at least two arguments";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        foreach (item; context.items)
        {
            if (item.type != ObjectType.SimpleList)
            {
                auto msg = "`" ~ path ~ "` expects a list of SimpleLists";
                return context.error(msg, ErrorCode.InvalidSyntax, "");
            }
            SimpleList l = cast(SimpleList)item;
            context.push(
                new String(l.items.map!(x => to!string(x)).join(joiner))
            );
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    stringCommands["strip"] = new Command((string path, Context context)
    {
        auto chars = context.pop!string();

        foreach (item; context.items)
        {
            string s = item.toString();
            context.push(new String(s.strip(chars)));
        }
        return context;
    });
    stringCommands["strip.left"] = new Command((string path, Context context)
    {
        auto chars = context.pop!string();

        foreach (item; context.items)
        {
            string s = item.toString();
            context.push(new String(s.stripLeft(chars)));
        }
        return context;
    });
    stringCommands["strip.right"] = new Command((string path, Context context)
    {
        auto chars = context.pop!string();

        foreach (item; context.items)
        {
            string s = item.toString();
            context.push(new String(s.stripRight(chars)));
        }
        return context;
    });
    stringCommands["find"] = new Command((string path, Context context)
    {
        string needle = context.pop!string();
        // TODO: make the following code template:
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` expects two arguments";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }
        foreach(item; context.items)
        {
            string haystack = item.toString();
            context.push(haystack.indexOf(needle));
        }
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });
    stringCommands["matches"] = new Command((string path, Context context)
    {
        string expression = context.pop!string();
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` expects two arguments";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }

        foreach (item; context.items)
        {
            string target = item.toString();

            SimpleList l = new SimpleList([]);
            foreach(m; target.matchAll(expression))
            {
                l.items ~= new String(m.hit);
            }
            context.push(l);
        }

        return context;
    });
    stringCommands["match"] = new Command((string path, Context context)
    {
        string expression = context.pop!string();
        if (context.size == 0)
        {
            auto msg = "`" ~ path ~ "` expects two arguments";
            return context.error(msg, ErrorCode.InvalidSyntax, "");
        }

        foreach (item; context.items)
        {
            string target = item.toString();

            foreach(m; target.matchFirst(expression))
            {
                context.push(m);
            }
        }

        return context;
    });
    stringCommands["range"] = new Command((string path, Context context)
    {
        /*
        range "12345" -> 1 , 2 , 3 , 4 , 5
        */
        class StringRange : Item
        {
            string s;
            int currentIndex = 0;
            ulong _length;

            this(string s)
            {
                this.s = s;
                this._length = s.length;
            }
            override string toString()
            {
                return "StringRange";
            }
            override Context next(Context context)
            {
                if (this.currentIndex >= this._length)
                {
                    context.exitCode = ExitCode.Break;
                }
                else
                {
                    auto chr = this.s[this.currentIndex++];
                    context.push(to!string(chr));
                    context.exitCode = ExitCode.Continue;
                }
                return context;
            }
        }

        string s = context.pop!string();
        context.push(new StringRange(s));
        context.exitCode = ExitCode.CommandSuccess;
        return context;
    });

    // Operators
    stringCommands["eq"] = new Command((string path, Context context)
    {
        if (context.size < 2)
        {
            auto msg = "`" ~ path ~ "` expects at least 2 arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "int");
        }

        string first = context.pop!string();
        foreach (item; context.items)
        {
            if (item.toString() != first)
            {
                return context.push(false);
            }
        }
        return context.push(true);
    });
    stringCommands["=="] = stringCommands["eq"];
    stringCommands["neq"] = new Command((string path, Context context)
    {
        if (context.size < 2)
        {
            auto msg = "`" ~ path ~ "` expects at least 2 arguments";
            return context.error(msg, ErrorCode.InvalidArgument, "int");
        }

        string first = context.pop!string();
        foreach (item; context.items)
        {
            if (item.toString() == first)
            {
                return context.push(false);
            }
        }
        return context.push(true);
    });
    stringCommands["!="] = stringCommands["neq"];

    // Conversions
    stringCommands["to.int"] = new Command((string path, Context context)
    {
        foreach (item; context.items)
        {
            string target = item.toString();

            auto result = toLong(target);
            if (!result.success)
            {
                auto msg = "Could not convert to integer";
                return context.error(msg, ErrorCode.InvalidArgument, "");
            }

            context.push(result.value);
        }
        return context;
    });
    stringCommands["to.float"] = new Command((string path, Context context)
    {
        foreach (item; context.items)
        {
            string target = item.toString();

            if (target.length == 0)
            {
                target = "0.0";
            }

            float result;
            try
            {
                result = to!float(target);
            }
            catch (ConvException)
            {
                auto msg = "Could not convert to float";
                return context.error(msg, ErrorCode.InvalidArgument, "");
            }

            context.push(result);
        }
        return context;
    });
    stringCommands["to.ascii"] = new Command((string path, Context context)
    {
        foreach (item; context.items)
        {
            string s = item.toString();
            if (s.length != 1)
            {
                auto msg = "Could not convert " ~ s ~ "to ascii";
                return context.error(msg, ErrorCode.InvalidArgument, "");
            }
            long i = cast(long)(s[0]);
            context.push(i);
        }

        return context;
    });
}
