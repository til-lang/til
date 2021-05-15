# Til is very opinionated

**Very.**

## One space only

The number of spaces does count. Not counting indentation, it should
always be **one**.

```tcl
io.out "Starting"  #  1 space = ok
exec   ls /        #  Why? WHY WOULD YOU DO THAT???
```

## No tabs

Do not indent code using "tab".

## No uppercase on NameAtoms

Every name must use **snake case**. Always. Because nobody wants to know
what are the rules to write "*has gRPC API URL*". It should be obvious:
`has_grpc_api_url`.
