module til.nodes;

import std.conv : to;
import std.stdio : writeln;
import std.algorithm.iteration : map, joiner;

import til.escopo;
import til.exceptions;


class Atom {
    private string _repr;
    @property string repr()
    {
        return _repr;
    }
    @property void repr(string s)
    {
        _repr = s;
    }
    private int _integer;
    @property int integer()
    {
        return _integer;
    }
    private float _floating_point;
    @property float floating_point()
    {
        return _floating_point;
    }

    this(string s)
    {
        repr = s;
    }

    override string toString()
    {
        return _repr;
    }
}

class ListItem
{
    SubProgram _subProgram;
    DotList _dotList;

    this(SubProgram sp)
    {
        _subProgram = sp;
    }
    this(DotList dl)
    {
        _dotList = dl;
    }

    bool isSubProgram()
    {
        return _subProgram !is null;
    }

    @property SubProgram subProgram()
    {
        return _subProgram;
    }

    override string toString()
    {
        if (_subProgram) {
            return to!string(_subProgram);
        } else {
            return to!string(_dotList);
        }
    }

    SubProgram run(Escopo escopo, ListItem[] arguments)
    {
        writeln("Running: " ~ to!string(this) ~ "  " ~ to!string(arguments));
        if (this.isSubProgram)
        {
            throw new InvalidException("ListItem: Cannot execute SubProgram");
        }
        return _dotList.run(escopo, arguments);
    }
}

class DotList
{
    ColonList[] _colonLists;

    this(ColonList[] colonLists)
    {
        _colonLists = colonLists;
    }

    override string toString()
    {
        auto list = _colonLists
            .map!(x => to!string(x))
            .joiner(".");
        return to!string(list);
    }

    SubProgram run(Escopo escopo, ListItem[] arguments)
    {
        // Only scope.* names have length=1:
        if (_colonLists.length == 1)
        {
            switch(to!string(this))
            {
                case "set":
                    return escopo.set(arguments);
                case "run":
                    return escopo.run(arguments);
                case "fill":
                    return escopo.fill(arguments);
                case "return":
                    return escopo.retorne(arguments);
                default:
                    return escopo.run_command(this, arguments);
            }
        }
        // TODO: user-created commands:
        else
        {
        }

        throw new NotFound("Command not found: " ~ to!string(this));
    }
}

class ColonList
{
    Atom[] _atoms;
    this(Atom[] atoms)
    {
        _atoms = atoms;
    }

    override string toString()
    {
        auto list = _atoms
            .map!(x => to!string(x))
            .joiner("-colon-");
        return to!string(list);
    }
}

class SubProgram
{
    Expression[] _expressions;
    SubProgram returnValue = null;

    this(Expression[] expressions)
    {
        _expressions = expressions;
    }

    override string toString()
    {
        auto list = _expressions
            .map!(x => to!string(x))
            .joiner("\n");
        return to!string(list);
    }

    ulong length()
    {
        return _expressions.length;
    }

    SubProgram run(Escopo parentEscopo)
    {
        // This is a new SubProgram, so we should
        // create our own scope:
        Escopo escopo = new Escopo(parentEscopo);
        SubProgram returned = null;

        foreach(expression; _expressions)
        {
            writeln("SubProgram.run-expression> " ~ to!string(expression));
            // XXX: fill "firstArguments" with "argv", maybe...
            returned = expression.run(escopo, null);
            writeln(" - returned: " ~ to!string(returned));

            if (returned !is null) {
                if (returned.returnValue) {
                    return returned.returnValue;
                }
            }
        }

        if (_expressions.length == 1)
        {
            // Returns whatever was the result of the last Expression,
            // but only for a SubProgram composed of only one Expression:
            return returned;
        }
        else
        {
            return null;
        }
    }
}

class Expression
{
    ForwardExpression _forwardExpression;
    ExpansionExpression _expansionExpression;
    List _list;
    string _string;

    this(ForwardExpression expr)
    {
        _forwardExpression = expr;
    }
    this(ExpansionExpression expr)
    {
        _expansionExpression = expr;
    }
    this(List l)
    {
        _list = l;
    }
    this(string s)
    {
        _string = s;
    }

    override string toString()
    {
        string x = {
            if (_forwardExpression) {
                return to!string(_forwardExpression);
            } else if (_expansionExpression) {
                return to!string(_expansionExpression);
            } else if (_list) {
                return to!string(_list);
            } else {
                return _string;
            }
        }();
        return x;
    }

    SubProgram run(Escopo escopo, ListItem[] firstArguments)
    {
        if (_forwardExpression) {
            return _forwardExpression.run(escopo, firstArguments);
        } else if (_expansionExpression) {
            return _expansionExpression.run(escopo, firstArguments);
        } else if (_list) {
            return _list.run(escopo, firstArguments);
        } else {
            // XXX: this is WEIRD!
            auto expressions = new Expression[1];
            expressions[0] = this;
            auto sp = new SubProgram(expressions);
            return sp;
        }
    }
}


class ExpressionSet
{
    Expression[] _expressions;
    this(Expression[] expressions)
    {
        _expressions = expressions;
    }
}

class ForwardExpression : ExpressionSet
{
    this(Expression[] expressions)
    {
        super(expressions);
    }

    override string toString()
    {
        auto exp1 = to!string(_expressions[0]);
        auto exp2 = to!string(_expressions[1]);
        return "f(" ~ exp1 ~ " > " ~ exp2 ~ ")f";
    }

    SubProgram run(Escopo escopo, ListItem[] firstArguments)
    {
        SubProgram returned = null;

        foreach(expression; _expressions)
        {
            writeln("ForwardExpression.run> " ~ to!string(expression));
            returned = expression.run(escopo, firstArguments);
            if (returned !is null)
            {
                if (returned.returnValue)
                {
                    return returned.returnValue;
                }
                // update firstArguments:
                firstArguments = new ListItem[1];
                firstArguments[0] = new ListItem(returned);
            }
            else
            {
                firstArguments = null;
            }
        }
        return returned;
    }
}

class ExpansionExpression : ExpressionSet
{
    this(Expression[] expressions)
    {
        super(expressions);
    }

    override string toString()
    {
        auto exp1 = to!string(_expressions[0]);
        auto exp2 = to!string(_expressions[1]);
        return "e(" ~ exp1 ~ " < " ~ exp2 ~ ")e";
    }

    SubProgram run(Escopo escopo, ListItem[] firstArguments)
    {
        SubProgram returned = null;

        foreach(expression; _expressions)
        {
            returned = expression.run(escopo, firstArguments);
            if (returned !is null)
            {
                if (returned.returnValue) {
                    return returned.returnValue;
                }

                // update firstArguments:
                // XXX: CHUNCHO
                auto returnedExpression = returned._expressions[0];
                auto returnedList = returnedExpression._list;
                firstArguments = returnedList._items;
            }
            else
            {
                firstArguments = null;
            }
        }
        return returned;
    }
}

class List
{
    ListItem[] _items;

    this(ListItem[] items)
    {
        _items = items;
        Expression[] expressions;
    }

    override string toString()
    {
        auto list = _items
            .map!(x => to!string(x))
            .joiner(" , ");
        return "[" ~ to!string(list) ~ "]";
    }

    SubProgram run(Escopo escopo, ListItem[] firstArguments)
    {
        // std.out 1 2 3
        ListItem command = _items[0];
        ListItem[] arguments;

        if (firstArguments !is null)
        {
            arguments = firstArguments ~ _items[1..$];
        }
        else
        {
            arguments = _items[1..$];
        }

        if (command.isSubProgram)
        {
            // It is NOT a "SubProgram", actually, but simply a string.

            if (arguments.length > 0)
            {
                throw new InvalidException(
                    "Cannot use a SubProgram as if it was a command"
                );
            }
            return command.subProgram;
        }

        auto strArguments = arguments
            .map!(x => to!string(x))
            .joiner(" , ");
        return command.run(escopo, arguments);
    }
}
