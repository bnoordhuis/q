q
=

quick way of querying google gemini and openai compatible llms from the
command line

```
$ cp q /usr/local/bin # or anywhere else that's on your PATH

```

```
$ cat > ~/.q
{
    "gemini": {
        "url": "https://generativelanguage.googleapis.com/v1beta/interactions",
        "key": "superdupersecret",
        "models": [
            "gemini-3.8-flash",
            "gemini-3.7-flash",
            "gemini-3.6-flash",
            "gemini-3.5-flash",
            "gemini-3.1-flash-lite",
            "gemini-2.5-flash"
        ]
    },
    "openrouter": {
        "url": "https://openrouter.ai/api/v1/chat/completions",
        "key": "superdupersecret",
        "models": ["openrouter/free"]
    }
}
```
get a gemini key here: https://aistudio.google.com/app/apikey
get an openrouter key here: https://openrouter.ai/openrouter/free

```
$ q how many litres of water does the north sea contain
Approximately 54,000 cubic kilometers, or 54 trillion liters.
```

```
# pipe in additional context
$ cat LICENSE | q what license is this
ISC license.
```
