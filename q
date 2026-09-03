#!/usr/bin/env node
const {exit} = process
import {homedir} from "node:os"
import {inspect} from "node:util"
import {readFileSync} from "node:fs"
import {text} from "node:stream/consumers"
inspect.defaultOptions.depth = 42

const pp = console.log
let verbose = x => x
let model

// first one is the default
const models = `
    gemini-3.8-flash
    gemini-3.7-flash
    gemini-3.6-flash
    gemini-3.5-flash
    gemini-3.5-flash-lite
    gemini-3.1-flash-lite
    gemini-2.5-flash
`.trim().split(/\s+/)

const key = readFileSync(homedir() + "/.q", "utf8").trim()
const args = process.argv.slice(2)

while (args.length && args[0].startsWith("-")) {
    let arg = args.shift()
    switch (arg) {
    case "-m":
        arg = String(args.shift())
        for (const s of models) {
            if (s.includes(arg)) {
                model = s
                break
            }
        }
        if (!model) {
            pp(`no such model: ${arg}`)
            exit()
        }
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
        pp(` -m <model> one of ${models.join(",")}`)
        pp(` -v         verbose mode`)
    }
}

if (!model) model = models[0]

let input
if (process.stdin.isTTY) {
    input = args.join(" ")
} else {
    input = await text(process.stdin)
}

const body = verbose({
    system_instruction: {
        parts: [
            {text: "Use a brief style with short replies."},
            {text: "Don't use markup unless asked to."},
            {text: "Don't leave out information."},
            {text: "Don't use filler words."},
        ],
    },
    contents: {
        parts: [
            {text: input},
        ],
    },
    tools: {
        "google_search": {
        },
    },
})

const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`
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
for (const candidate of json.candidates) {
    for (const part of candidate.content.parts) {
        pp(part.text)
    }
}
