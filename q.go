// Copyright (c) 2025, Ben Noordhuis <info@bnoordhuis.nl>
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"github.com/mattn/go-isatty"
	"io"
	"net/http"
	"os"
	"path"
	"strings"
)

type request struct {
	Contents content `json:"contents"`
	System   content `json:"system_instruction"`
}

type response struct {
	Candidates []candidates `json:"candidates"`
}

type candidates struct {
	Content content `json:"content"`
}

type content struct {
	Parts []part `json:"parts"`
}

type part struct {
	Text string `json:"text"`
}

func main() {
	system := []part{
		part{Text: "Answer in as few words as possible. Use a brief style with short replies."},
	}
	parts := []part{}
	if !isatty.IsTerminal(os.Stdin.Fd()) {
		query, err := io.ReadAll(os.Stdin)
		dieIf(err)
		part := part{Text: string(query)}
		parts = append(parts, part)
	}
	query := strings.TrimSpace(strings.Join(os.Args[1:], " "))
	if query != "" {
		part := part{Text: string(query)}
		parts = append(parts, part)
	}
	if len(parts) == 0 {
		os.Exit(1)
	}
	home, err := os.UserHomeDir()
	dieIf(err)
	filename := path.Join(home, ".q")
	key, err := os.ReadFile(filename)
	dieIf(err)
	url := "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key="
	url += strings.TrimSpace(string(key))
	body, err := json.Marshal(request{
		System:   content{Parts: system},
		Contents: content{Parts: parts},
	})
	dieIf(err)
	r, err := http.Post(url, "application/json", bytes.NewReader(body))
	dieIf(err)
	if r.StatusCode != 200 {
		_, _ = io.Copy(os.Stderr, r.Body)
		os.Exit(1)
	}
	b, err := io.ReadAll(r.Body)
	dieIf(err)
	var res response
	dieIf(json.Unmarshal(b, &res))
	for _, c := range res.Candidates {
		for _, p := range c.Content.Parts {
			fmt.Printf("%s", p.Text)
		}
	}
}

func dieIf(err error) {
	if err != nil {
		fmt.Fprintf(os.Stderr, "q: %s\n", err)
		os.Exit(1)
	}
}
