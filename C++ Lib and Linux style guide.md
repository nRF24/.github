# Clang-format
We use [clang-format v12](https://releases.llvm.org/12.0.0/tools/clang/docs/ClangFormatStyleOptions.html)
to conform our code style according to the rules outlined below.

@note These rules are applied to any C/C++ source code that is not Arduino example code. For the code style used in the Arduino examples, please refer to the [Arduino example formatting style guide](https://docs.arduino.cc/learn/contributions/arduino-writing-style-guide).

- Indentation should always be 4 spaces (don't use tab characters)
- Line endings can be whatever your system defaults to. We have configured git to convert
  line endings into Unix style LF. This means that when you develop (and push commits) from
  a Windows machine, the CRLF line endings are automatically converted to LF line endings.

## `AccessModifierOffset: -4`

Any data structure with explicit access modifiers (`public`, `private`, or `protected`)
should carry the same indentation as the data structure's declaration.

```cpp
class MyClass {
public:
}
```

## `AlignAfterOpenBracket: Align`

Align parameters on the open bracket.

```cpp
someLongFunction(argument1,
                 argument2);
```

## `AlignConsecutiveMacros: Consecutive`

Align macro definitions on consecutive lines.

```cpp
#define SHORT_NAME       42
#define LONGER_NAME      0x007f
#define EVEN_LONGER_NAME (2)

#define foo(x) (x * x)
/* some comment */
#define bar(y, z) (y + z)
```

## `AlignEscapedNewlines: Left`

Align escaped newlines as far left as possible.

```cpp
#define A   \
  int aaaa; \
  int b;    \
  int dddddddddd;
```

## `AlignTrailingComments: true`

For consecutive lines in a "paragraph" that have trailing comments,
the comments should be aligned vertically. The aligning column is 1 space after the
longest line in the "paragraph".

See also `SpacesBeforeTrailingComments`

```cpp
int a;     // My comment a
int b = 2; // comment  b
```

## `AllowAllArgumentsOnNextLine: true`

If a function call or braced initializer list doesn't fit on a line, allow putting all arguments onto the next line.

```cpp
callFunction(
    a, b, c, d);
```

## `AllowAllConstructorInitializersOnNextLine: true`

If a constructor definition with a member initializer list doesn't fit on a single line, allow putting all member initializers onto the next line.

```cpp
MyClass::MyClass() :
    member0(0), member1(2) {}
```

## `AllowAllParametersOfDeclarationOnNextLine: true`

If the function declaration doesn't fit on a line, allow putting all parameters of a function
declaration onto the next line.

```cpp
void myFunction(
    int a, int b, int c, int d, int e);
```

## `AllowShortEnumsOnASingleLine: true`

Allow short enums on a single line.

```cpp
enum { A, B } myEnum;
```

## `AllowShortBlocksOnASingleLine: Always`

Always merge short blocks into a single line.

```cpp
while (true) {}
while (true) { continue; }
```

## `AllowShortCaseLabelsOnASingleLine: false`

Short case labels should always get their own separate line(s).

```cpp
switch (a) {
case 1:
    x = 1;
    break;
case 2:
    return;
}
```

## `AllowShortFunctionsOnASingleLine: All`

Merge all functions fitting on a single line.

```cpp
class Foo {
    void f() { foo(); }
};
void f() { bar(); }
```

## `AllowShortLambdasOnASingleLine: All`

Merge all lambdas fitting on a single line.

```cpp
auto lambda = [](int a) {}
auto lambda2 = [](int a) { return a; };
```

## `AllowShortIfStatementsOnASingleLine: WithoutElse`

Put short `if`s on the same line only if the `else` is not a compound statement.

```cpp
if (a) return;
else
    return;
```

## `AllowShortLoopsOnASingleLine: true`

Short loops can be put on a single line.

```cpp
while (true) continue;
```

## `AlwaysBreakAfterReturnType: None`

A function's return type should not get its own line.

```cpp
class A {
    int f() { return 0; };
};
int f();
int f() { return 1; }
```

## `AlwaysBreakBeforeMultilineStrings: false`

This flag is mean to make cases where there are multiple multiline strings in a file look
more consistent. The subsequent indent should align with the beginning of the string.

```cpp
aaaa = "bbbb"
       "cccc";
```

## `AlwaysBreakTemplateDeclarations: Yes`

Always break after template declaration.

```cpp
template <typename T>
T foo() {
}
template <typename T>
T foo(int aaaaaaaaaaaaaaaaaaaaa,
      int bbbbbbbbbbbbbbbbbbbbb) {
}
```

## `BinPackArguments: true`

A function call's multitude of arguments can span multiple lines without needing
1 line per argument.

```cpp
void f() {
  f(aaaaaaaaaaaaaaaaaaaa, aaaaaaaaaaaaaaaaaaaa,
    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa);
}
```

## `BinPackParameters: true`

A function declaration's multitude of arguments can span multiple lines without needing
1 line per argument.

```cpp
void f(int aaaaaaaaaaaaaaaaaaaa, int aaaaaaaaaaaaaaaaaaaa,
       int aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa) {}
```

## `BitFieldColonSpacing: Both`

Add one space on each side of the `:`

```cpp
unsigned bf : 2;
```

## BraceWrapping

Control of individual brace wrapping cases.

### `AfterCaseLabel: false`

```cpp
switch (foo) {
    case 1: {
        bar();
        break;
    }
    default: {
        plop();
    }
}
```

### `AfterClass: true`

```cpp
class foo {};
```

### `AfterControlStatement: MultiLine`

Only wrap braces after a multi-line control statement (`if`/`for`/`while`/`switch`/...).

```cpp
if (foo && bar &&
    baz)
{
    qux();
}
while (foo || bar) {
}
```

### `AfterEnum: true`

```cpp
enum X : int
{
    B
};
```

### `AfterFunction: true`

```cpp
void foo()
{
    bar();
    bar2();
}
```

### `AfterNamespace: false`

```cpp
namespace {
int foo();
int bar();
}
```

### `AfterStruct: true`

```cpp
struct foo
{
    int x;
};
```

### `AfterUnion: true`

```cpp
union foo
{
   int x;
}
```

### `AfterExternBlock: false`

```cpp
extern "C" {
int foo();
}
```

### `BeforeCatch: true`

```cpp
try {
    foo();
}
catch () {
}
```

### `BeforeElse: true`

```cpp
if (foo()) {
}
else {
}
```

### `BeforeLambdaBody: false`

```cpp
connect([]() {
    foo();
    bar();
});
```

### `BeforeWhile: false`

```cpp
do {
  foo();
} while (1);
```

### `SplitEmptyRecord: true`

```cpp
class Foo()
{
}
```

## `BreakBeforeBinaryOperators: All`

Break before binary operators whose operands span multiple lines.

```cpp
VeryVeryVeryVeryVeryLongType veryVeryVeryVeryVeryLongVariable
    = someVeryVeryVeryVeryLongFunction();

bool value = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
                     + aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
                 == aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
             && aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
                    > ccccccccccccccccccccccccccccccccccccccccc;
```

## `BreakBeforeConceptDeclarations: true`

Concept should be placed on a new line.

```cpp
template<typename T>
concept ...
```

## `BreakInheritanceList: BeforeColon`

Break inheritance list before the colon and after the commas.

```cpp
class Foo
    : Base1,
      Base2
{};
```

## `BreakBeforeTernaryOperators: true`

Ternary operators should be placed after line breaks (if the operands span multiple lines).

```cpp
veryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryLongDescription
    ? firstValue
    : SecondValueVeryVeryVeryVeryLong;
```

## `BreakConstructorInitializers: BeforeColon`

Break constructor initializers before the colon and after the commas.

```cpp
Constructor()
    : initializer1(),
      initializer2()
```

## `BreakStringLiterals: true`

Breaking string literals into multiple lines is allowed.

```cpp
const char* x = "veryVeryVeryVeryVeryVe"
                "ryVeryVeryVeryVeryVery"
                "VeryLongString";
```

## `ColumnLimit: 0`

There is no line length limit.

## `CompactNamespaces: false`

Each namespace is declared on a new line.

```cpp
namespace Foo {
namespace Bar {
}
}
```

## `Cpp11BracedListStyle: true`

format braced lists as best suited for C++11 braced lists.

Important differences:

- No spaces inside the braced list.
- No line break before the closing brace.
- Indentation with the continuation indent, not with the block indent.

```cpp
vector<int> x{1, 2, 3, 4};
vector<T> x{{}, {}, {}, {}};
f(MyMap[{composite, key}]);
new int[3]{1, 2, 3};
```

## `EmptyLineBeforeAccessModifier: Always`

Always add empty line before access modifiers unless access modifier is at the start of struct or class definition.

```cpp
struct foo {
private:
    int i;

protected:
    int j;
    /* comment */

public:
    foo() {}

private:

protected:
};
```

## `FixNamespaceComments: true`

Add namespace end comments.

```cpp
namespace a {
foo();
} // namespace a
```

## `IndentCaseLabels: true`

Switch statement body is always indented one level more than case labels (except the first block following the case label, which itself indents the code)

```cpp
switch (fool) {
  case 1:
    bar();
    break;
  default:
    plop();
}
```

## `IndentGotoLabels : false`

Goto labels are flushed left.

```cpp
int f() {
  if (foo()) {
label1:
    bar();
  }
label2:
  return 1;
}
```

## `IndentPPDirectives: BeforeHash`

Indents directives before the hash.

```cpp
#if FOO
  #if BAR
    #include <foo>
  #endif
#endif
```

## `IndentExternBlock: AfterExternBlock`

Do not indent extern blocks.

```cpp
extern "C" {
void foo();
}
```

## `IndentRequires: false`

Do not indent the requires clause in a template.

```cpp
template <typename It>
requires Iterator<It>
void sort(It begin, It end) {
  //....
}
```

## `IndentWidth: 4`

Indentation is 4 spaces.

## `IndentWrappedFunctionNames: false`

Do not Indent if a function definition or declaration is wrapped after the type.

```cpp
LoooooooooooooooooooooooooooooooooooooooongReturnType
LoooooooooooooooooooooooooooooooongFunctionDeclaration();
```

## `KeepEmptyLinesAtTheStartOfBlocks: true`

The (optional) empty line at the start of blocks is kept.

```cpp
if (foo) {

  bar();
}
```

## `MaxEmptyLinesToKeep: 1`

Consecutive empty lines are reduced to 1.

## `NamespaceIndentation: Inner`

Indent only in inner namespaces (nested in other namespaces).

```cpp
namespace out {
int i;
namespace in {
  int i;
}
}
```

## `PointerAlignment: Left`

Align pointer to the left.

```cpp
int* a;
```

## `ReflowComments: true`

This is only applicable if we decide to impose a line length (which we are not)

```cpp
// veryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryLongComment with plenty of
// information
/* second veryVeryVeryVeryVeryVeryVeryVeryVeryVeryVeryLongComment with plenty of
 * information */
```

## `SpaceAfterCStyleCast: false`

Do not insert a space after C style casts.

```c
(int)i;
```

## `SpaceAfterLogicalNot: false`

Do not insert a space after the logical not operator (`!`).

```cpp
!someExpression();
```

## `SpaceAfterTemplateKeyword: false`

Do not insert a space after the `template` keyword.

```cpp
template<int> void foo();
```

## `SpaceBeforeAssignmentOperators: true`

A spaces will be inserted before assignment operators.

```cpp
int a = 5;
a += 42;
```

## `SpaceBeforeCaseColon: false`

Spaces will be removed before case colon.

```cpp
switch (x) {
  case 1: break;
}
```

## `SpaceBeforeCpp11BracedList: true`

A space will be inserted before a C++11 braced list used to initialize an object (after the preceding identifier or type).

```cpp
Foo foo { bar };
Foo {};
vector<int> { 1, 2, 3 };
new int[3] { 1, 2, 3 };
```

## `SpaceBeforeCtorInitializerColon: true`

A space will be inserted before a constructor initializer colon.

```cpp
Foo::Foo() : a(a) {}
```

## `SpaceBeforeInheritanceColon: true`

A space will be inserted before a inheritance colon.

```cpp
class Foo : Bar {}
```

## `SpaceBeforeParens: ControlStatements`

Put a space before opening parentheses only after control statement keywords (`for`/`if`/`while`...).

```cpp
void f() {
  if (true) {
    f();
  }
}
```

## `SpaceBeforeRangeBasedForLoopColon: true`

A space will be inserted before a range-based for loop colon.

```cpp
for (auto v : values) {}
```

## `SpaceInEmptyParentheses: false`

Do not use spaces for an empty set of parenthesis.

```cpp
void f() {
    int x[] = {foo(), bar()};
}
```

## `SpacesBeforeTrailingComments: 1`

Use a space before trailing line comments (`//` - comments).

This does not affect trailing block comments (`/*` - comments) as those commonly have different usage patterns and a number of special cases.

```cpp
void f() {
  if (true) { // foo1
    f();      // bar
  }           // foo
}
```

## `SpacesInAngles: false`

Spaces will be removed after `<` and before `>` in template argument lists.

```cpp
static_cast<int>(arg);
std::function<void(int)> fct;
```

## `SpacesInConditionalStatement: false`

Spaces will be removed around `if`/`for`/`switch`/`while` conditions.

```cpp
if (a) { ... }
while (i < 5) { ... }
```

## `SpacesInContainerLiterals: false`

Spaces are inserted inside container literals.

```cpp
var arr = [1, 2, 3];
f({a: 1, b: 2, c: 3});
```

## `SpacesInCStyleCastParentheses: false`

Spaces will be removed from C style casts.

```c
x = (int32)y;
```

## `SpacesInParentheses: false`

Spaces will be removed after `(` and before `)`.

```cpp
t f(Deleted &) & = delete;
```

## `SpacesInSquareBrackets: false`

Spaces will be removed after `[` and before `]`.

```cpp
int a[5];
```

## `SpaceBeforeSquareBrackets: false`

Spaces will be removed before `[`.

```cpp
int a[5];
int a[5][5];
```

## `Standard: c++11`

Follow the C++11 standard format.

## `TabWidth: 4`

A tab's width is considered equal to 4 spaces.

## `UseTab: Never`

Only use spaces (not tabs).

## `UseCRLF: false`

This project is primarily for Linux platforms, so we prefer to have LF line endings. We don't use Windows-style CRLF line endings.
