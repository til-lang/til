module til.exceptions;


class InvalidException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

class NotFound : Exception
{
    this(string msg)
    {
        super(msg);
    }
}
