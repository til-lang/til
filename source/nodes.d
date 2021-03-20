module til.nodes;

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
}

class DotList
{
    ColonList[] _colonLists;

    this(ColonList[] colonLists)
    {
        _colonLists = colonLists;
    }
}

class ColonList
{
    Atom[] _atoms;
    this(Atom[] atoms)
    {
        _atoms = atoms;
    }
}

class SubProgram
{
    Expression[] _expressions;

    this(Expression[] expressions)
    {
        _expressions = expressions;
    }
}

class Expression
{
    ForwardExpression _forwardExpression;
    ExpansionExpression _expansionExpression;
    List _list;

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
}

class ExpansionExpression : ExpressionSet
{
    this(Expression[] expressions)
    {
        super(expressions);
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
}
