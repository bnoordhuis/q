#!/usr/bin/env node
const {exit} = process
import {homedir} from "node:os"
import {inspect} from "node:util"
import {readFileSync} from "node:fs"
import {text} from "node:stream/consumers"
inspect.defaultOptions.depth = 42

const url = "https://generativelanguage.googleapis.com/v1beta/interactions"
const system = `
    Use a brief style with short replies.
    Don't use markup unless asked to.
    Don't leave out information.
    Don't use filler words.
`.trim().replace(/\s+/g, ' ')

const pp = console.log
let verbose = x => x
let model

const models = `
    gemini-3.8-flash
    gemini-3.7-flash
    gemini-3.6-flash
    gemini-3.5-flash
    gemini-3.5-flash-lite
    gemini-3.1-flash-lite
    gemini-2.5-flash
`.trim().split(/\s+/)

models.get = function(pattern) {
    for (const model of this)
        if (model.includes(pattern))
            return model
}
// pick the first flash-lite model
models.default = function() { return this.get("flash-lite") }

const key = readFileSync(homedir() + "/.q", "utf8").trim()
const args = process.argv.slice(2)

while (args.length && args[0].startsWith("-")) {
    let arg = args.shift()
    switch (arg) {
    case "-m":
        arg = String(args.shift())
        model = models.get(arg) ?? arg // if no match, assume user knows best
        break
    case "-v":
        verbose = x => { pp(x); return x }
        break
    default:
        pp(`bad argument: ${arg}`)
        // fallthru
    case "-h":
        pp(`options:`)
        pp(` -h         this help message`)
        pp(` -m <model> one of: ${models.join(" ")}`)
        pp(`            default: ${models.default()}`)
        pp(` -v         verbose mode`)
        exit()
    }
}

if (!model) model = models.default()

let input
if (process.stdin.isTTY) {
    input = args.join(" ")
} else {
    input = await text(process.stdin)
}

const tools = [
    {type: "google_maps"},
    {type: "google_search"},
    /*
    {
        type: "function",
        description: "Tell the user what the important keywords in the response text are",
        name: "highlight",
        parameters: {
            type: "object",
            required: ["keywords"],
            properties: {
                keywords: {
                    type: "array",
                    items: {type: "string"},
                    description: "An array of text strings that must be highlighted",
                },
            },
        },
    },
    */
]
const body = verbose({model, input, tools, system_instruction: system})
const res = await fetch(url, {
    body: JSON.stringify(body),
    method: "POST",
    headers: {
        "content-type": "application/json",
        "x-goog-api-key": key,
    },
})

if (!res.ok) {
    pp(await res.text())
    exit(1)
}

const json = verbose(await res.json())
for (const step of json.steps) {
    switch (step.type) {
    case "model_output":
        for (const content of step.content) {
            pp(pretty(content.text.trim()))
        }
        break
    default:
        verbose(`[skipping step ${step.type}]`)
    }
}

function pretty(s) {
    if (!process.stdout.isTTY) return s
    // must come first: replaces numbers, passes below insert numbers
    s = s.replace(/\d+/g, s => {
        s = `\x1B[33m${s}\x1B[0m`
        return s
    })
    s = s.replace(/([*][*].+?[*][*])/g, s => {
        s = s.slice(2, -2)
        s = `\x1B[1;31m${s}\x1B[0m`
        return s
    })
    s = s.replace(/[*][^*]+[*]/g, s => {
        s = s.slice(1, -1)
        s = `\x1B[1m${s}\x1B[0m`
        return s
    })
    return s
}
