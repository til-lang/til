module til.exceptions;


template customException(string name)
{
    const string customException = "
class " ~ name ~ " : Exception
{
    this(string msg)
    {
        super(msg);
    }
}
    ";
}

mixin(customException!"InvalidException");
mixin(customException!"NotFoundException");
