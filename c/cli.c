#include <stdio.h>
#include <stdlib.h>
#include "til.h"


int main(int argc, char** argv)
{
    size_t scope = til_new_scope("main", 0);
    int exit_code = til_eval(scope, "test program", "\
        set a 1\n\
        set b 2\n\
        set result $($a + $b)\n\
    ");
    if (exit_code != 0)
    {
        printf("Error %d while executing Til program", exit_code);
        exit(exit_code);
    }

    long result = til_get_integer_value(scope, "result");
    if (result == 3)
    {
        printf("Correct! The result is %d!", result);
        exit(0);
    }
    else
    {
        printf("Wrong! The result should not be %d!", result);
        exit(1);
    }
}
