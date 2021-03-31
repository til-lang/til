# Language


```tcl
set x 1234
set y 56.78
set result [math.run {$x + $y}]
```

## Line 1

* `set x 1234`
* set=Atom; x=Atom; 1234=Atom(int:1234)
* List: (set, x, 1234)
* List.run
* scope[x] = (1234)

## Line 2

* `set y 56.78`
* set=Atom; y=Atom; 56.78=Atom(float:56.78)
* List: (set, y, 56.78)
* List.run
* scope[y] = (56.78)

## Line 3

* `set result [math.run {$x + $y}]`
* set=Atom; result=Atom, +ExecList
* ExecList: (math.run=Atom, +SubList)
* SubList: ($x=Atom, +=Atom, $y=Atom)
* SubList.evaluation: ((1234)=List, +=Atom, (56.78)=List)
* (1234) = List(ListItem(Atom(1234)))
