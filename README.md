q
=

quick way of querying google's gemini 2.0 flash llm from the command line

```
$ go build

$ cp q /usr/local/bin # or anywhere else that's on your PATH

$ cat > ~/.q
<paste your api key here>

$ q how many litres of water does the north sea contain
Approximately 54,000 cubic kilometers, or 54 trillion liters.

# pipe in additional context
$ cat LICENSE | q what license is this
ISC license.
```
