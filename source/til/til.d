module til.til;

import pegged.grammar;


mixin(grammar(`
    Til:
        Program           <- List* blank* endOfInput
        Comment           <~ [ \t]* "#" (!eol .)*
        List              <- blank* ListItem (" " ListItem)*
        ListItem          <- Comment / Pipe / ExecList / SubList / SimpleList / String / Atom
        Pipe              <- ForwardPipe
        ForwardPipe       <- "|>"
        SimpleList        <- "(" List? ")"
        ExecList          <- "[" List* blank* "]"
        SubList           <- "{" List* blank* "}"
        String            <- ["] (Substitution / NotSubstitution)* ["]
        Substitution      <~ "$" [A-Za-z0-9_.]+
        NotSubstitution   <~ (!doublequote !"$" .)*
        Atom              <- Float / Integer / Boolean / Name / Operator / CommonAtom
        CommonAtom        <~ [$A-Za-z0-9_<>+\-_=.:&]+
        Name              <- NamePart ("." NamePart)* QuestionMark?
        NamePart          <~ [A-Za-z] [A-Za-z0-9_]*
        QuestionMark      <~ "?"
        Float             <~ [0-9]+ "." [0-9]+
        Integer           <~ [0-9]+
        Boolean           <- BooleanTrue / BooleanFalse
        BooleanTrue       <~ "true" / "yes"
        BooleanFalse      <~ "false" / "no"
        Operator          <~ "||" / "&&" / "<=" / ">=" / [&|+\-*/<>]
    `));
