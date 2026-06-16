# ollacc

> **Ollama Cloud Claude Code launcher.** Point Claude Code at any Ollama Cloud
> model — same `claude` command, just routed through `https://ollama.com`.

`ollacc` is **Ollama with Claude Code** — Claude Code talking straight
to the **Ollama cloud API** at `https://ollama.com`, with no local Ollama
install in the path.

Ollama ships in two pieces: a local server that runs on your box
(`localhost:11434`), and the cloud API at `https://ollama.com`. You can
already use cloud models through your local Ollama — `ollama pull
<cloud-model>` keeps just the manifest locally, no weights, and the local
server proxies each request up to ollama.com for you. That's what
`ollama launch claude` and similar local-Ollama-routed setups do: every
request comes into `localhost:11434` first, gets forwarded to the cloud,
and the response comes back through your box. Same cloud model, but your
local CPU and RAM are in the path on every call. Fine for one session —
painful when you swarm.

`ollacc` skips the local server entirely. It points Claude Code straight
at `https://ollama.com` — same cloud model, different path, no Ollama
install required. When you swarm, none of the parallel sessions have to
funnel through your box on the way to the cloud. The only constraint left
is your home network's reach to the internet.

`ollacc` is a thin wrapper that:

1. Manages your Ollama Cloud API key (one-time prompt, stored `chmod 600`).
2. Lets you pick a model from the **top 10 popular** Ollama Cloud models
   (scraped live from ollama.com's "Popular" sort, intersected with your
   auth'd cloud catalog — so you only see models you can actually call).
3. Remembers your choice as a default so the next run is a one-liner.
4. Execs `claude --model <name>` with the right env vars so the Anthropic SDK
   talks to Ollama's OpenAI-compatible endpoint.

## Install

One-liner (recommended):

```bash
curl -sSL https://raw.githubusercontent.com/dansasser/ollacc/main/install.sh | bash
```

…or clone and run:

```bash
git clone https://github.com/dansasser/ollacc.git
cd ollacc
./install.sh
```

The installer will:

- Create `~/.ollacc/` (chmod 700) and `~/.ollacc/config` (chmod 600).
- Copy the `ollacc` launcher into `~/.ollacc/ollacc` (chmod 755).
- Add the `ollacc` alias to your shell rc (`.zshrc` → `.bashrc` →
  `.bash_profile` → `.profile` — first one found wins; `.profile` is created
  if none exist).
- Be a no-op on re-run.

Reload your shell:

```bash
source ~/.zshrc   # or whichever rc the installer touched
```

## First run

```bash
ollacc
```

You'll see a splash explaining how to grab an API key at
<https://ollama.com/settings/keys>, then a silent prompt. Paste the key and
hit Enter. It's saved to `~/.ollacc/config` (chmod 600, only you can read it).

Then you get the top-10 model menu:

```
=============================================
   🤖 ollacc - Ollama Cloud Claude Code
=============================================
Select a cloud model to run:
---------------------------------------------
 1) kimi-k2.7-code
 2) glm-5.2
 3) minimax-m3
 4) nemotron-3-ultra
 5) glm-5.1
 6) minimax-m2.7
 7) nemotron-3-super
 8) glm-5
 9) minimax-m2.5
10) glm-4.7
11) [Custom] Enter your own model name
=============================================
```

After you pick, ollacc asks if you want to make it your default. If you say
yes, the next `ollacc` invocation skips the menu entirely.

## Usage

```bash
ollacc                     # use default model (or show menu if none set)
ollacc --model kimi-k2.7-code    # use a different model for this run only
ollacc --model-clear       # clear saved default; show menu next time
ollacc --key-clear         # clear saved API key; re-prompt next time
```

Any other flags are forwarded to `claude` after `--model <name>`:

```bash
ollacc -- --help           # passes --help to claude
ollacc -- --continue       # passes --continue to claude
```

(The `--` separator isn't strictly required, but it's the safe way to pass
flags that look like ollacc's own.)

## Key management

Your API key is stored in `~/.ollacc/config` (chmod 600):

```bash
ANTHROPIC_AUTH_TOKEN="ea04..."
ANTHROPIC_BASE_URL="https://ollama.com"
OLLAMA_CLAUDE_DEFAULT_MODEL="minimax-m3"
```

- **Edit it directly** if you prefer a manual workflow.
- **Clear it** with `ollacc --key-clear` — next run will re-prompt.
- The file is sourced by the launcher as bash, so you can use shell
  variables, comments, etc. Just keep the `KEY="..."` shape.

## Troubleshooting

**"Model not found" / 401 from the API**
Run `ollacc --key-clear` and re-enter your key. The Ollama Cloud API
returns 401 when the token is bad, and ollacc re-prompts cleanly.

**The model I want isn't in the top 10**
Pick option **11) [Custom]** and type the exact model name (e.g.
`qwen3-coder:480b`). You can also pin it as your default so you never see
the menu again.

**"ollacc: command not found" after install**
Your shell didn't pick up the new alias. Either:

- `source ~/.zshrc` (or whatever rc the installer reported), OR
- Open a new terminal.

**Default model stopped working / was removed from your catalog**
The fast path checks that the saved default still exists in your auth'd
catalog. If it doesn't, ollacc falls through to the menu and warns you.
Run `ollacc --model-clear` to wipe the stale default.

**I want to see what env vars ollacc is exporting**
The launcher only exports `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`,
and `ANTHROPIC_API_KEY=""` (the empty `ANTHROPIC_API_KEY` is required —
see [ollama/ollama#13854](https://github.com/ollama/ollama/issues/13854)).
Run `ollacc --model X -- some-claude-flag-that-dumps-env` to inspect from
within a Claude Code session.

## Uninstall

```bash
./uninstall.sh
```

Removes the `ollacc` alias from your rc files. You'll be asked whether to
also delete `~/.ollacc/` (which would wipe your saved API key — say `N` if
you plan to reinstall later and don't want to re-enter it).

## How it works (short version)

The Anthropic SDK reads three env vars to know where to send requests:

- `ANTHROPIC_BASE_URL` — bare host, SDK appends `/v1/messages`.
  For Ollama Cloud: `https://ollama.com` (no `/api/`, no trailing slash).
- `ANTHROPIC_AUTH_TOKEN` — the Bearer token.
- `ANTHROPIC_API_KEY` — must be **empty**, otherwise the SDK uses this and
  ignores `ANTHROPIC_AUTH_TOKEN`. (Counter-intuitive; see
  [ollama/ollama#13854](https://github.com/ollama/ollama/issues/13854).)

`ollacc` sets those, picks a model, and `exec`s `claude --model <name> ...`.

The "top 10 popular" list comes from scraping
<https://ollama.com/search?c=cloud> (the page's "Popular" sort order) and
intersecting those slugs with `https://ollama.com/api/tags` (your auth'd
catalog). No public API exists for the popular ordering, so the HTML is
the source of truth — meaning the menu tracks the actual ollama.com
rankings, not a hardcoded list that goes stale.

## License

MIT.
