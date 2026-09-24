#!/usr/bin/env node
const {exit} = process
import {homedir} from "node:os"
import {inspect} from "node:util"
import {readFileSync} from "node:fs"
import {text} from "node:stream/consumers"
const pp = console.log
let verbose = x => x
inspect.defaultOptions.depth = 42

const config = JSON.parse(readFileSync(homedir() + "/.q", "utf8"))
const models = []

for (const [_, provider] of Object.entries(config))
    for (const name of provider.models)
        models.push({name, key:provider.key, url:provider.url})

const system = `
    Use a brief style with short replies.
    Don't use markup unless asked to.
    Don't leave out information.
    Don't use filler words.
`.trim().replace(/\s+/g, ' ')

models.get = function(pattern) {
    for (const model of this)
        if (model.name.includes(pattern))
            return model
}
models.default = function() { return this.get("openrouter/free") }

let model
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
        pp(` -m <model> one of: ${models.map(m => m.name).join(" ")}`)
        pp(`            default: ${models.default().name}`)
        pp(` -v         verbose mode`)
        exit()
    }
}

let input
if (process.stdin.isTTY) {
    input = args.join(" ")
} else {
    input = await text(process.stdin)
}

if (!model) model = models.default()
const isGemini = model.url.includes('https://generativelanguage.googleapis.com')

const headers = {"content-type": "application/json"}
if (isGemini) {
    headers["x-goog-api-key"] = model.key
} else {
    headers["authorization"] = "Bearer " + model.key
}

let body
if (isGemini) {
    const tools = [
        {type: "google_maps"},
        {type: "google_search"},
    ]
    body = verbose({model: model.name, input, tools, system_instruction: system})
} else {
    const messages = [
        {role: "system", content: system},
        {role: "user", content: input},
    ]
    body = verbose({model: model.name, messages})
}
body = JSON.stringify(body)

const res = await fetch(model.url, {method:"POST", headers, body})
if (!res.ok) {
    pp(await res.text())
    exit(1)
}

const json = verbose(await res.json())
if (isGemini) {
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
} else {
    for (const choice of json.choices || []) {
        const msg = choice.message || {}
        pp(pretty(msg.content || ""))
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
