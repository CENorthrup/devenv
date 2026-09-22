# GitHub reviewer App

`devenv-reviewer[bot]` is the durable factory reviewer role. The model, effort and
harness that performed a review are recorded in its body, separately from GitHub
identity. This avoids attributing agent findings to Clay and allows an independent
identity to submit `COMMENT`, `APPROVE` or `REQUEST_CHANGES` on human-authored PRs.
The future worker identity remains out of scope; issue #7 remains its follow-up.

Clay retains final merge authority. This tool cannot merge, does not change branch
protection or bypass rules, and must never be used to impersonate human approval.
GitHub's `Pull requests: write` permission is broader than writing reviews; the
narrow command interface is not a stronger GitHub authorization boundary.

## One-time registration (Clay)

1. Open <https://github.com/settings/apps/new> under `CENorthrup`.
   Name the App **devenv-reviewer**. If unavailable or its resulting slug differs,
   stop and choose the name with Clay; do not invent an alternate name.
2. Set homepage URL to `https://github.com/CENorthrup/devenv` and description to
   `Independent factory agent reviews with model and commit provenance`.
   Leave callback/setup URLs blank. Leave user authorization, device flow and
   webhook **Active** disabled. No OAuth flow or webhook events are needed.
3. Repository permissions: **Pull requests: Read and write**, **Metadata: Read-only**
   (automatic). All other repository, organization and account permissions: none.
   Select **Only on this account** for where the App can be installed.
   Do not give the App branch-protection bypass rights.
4. Create the App and record its **App ID** (not Client ID). Confirm its public
   slug is `devenv-reviewer` at `https://github.com/apps/devenv-reviewer`.
5. Under **Install App**, select `CENorthrup`, **Only select repositories**, and
   **devenv** only. Record the installation ID from the resulting installation
   settings URL, `https://github.com/settings/installations/<installation-id>`.
6. Generate a private key in the App's settings. Store the downloaded PEM outside
   every checkout, at `~/.config/devenv-reviewer/private-key.pem` with mode `600`.
   Use a mode `700` directory. Do not paste the PEM, JWT or installation token into
   chat, a PR, shell arguments or logs. Do not distribute it to arbitrary VMs.
7. Create `~/.config/devenv-reviewer/config.json`, substituting the real IDs and
   absolute private-key path. These are local values and do not belong in Git:

   ```json
   {
     "app_id": "<App ID>",
     "installation_id": "<Installation ID>",
     "private_key_path": "/absolute/path/to/.config/devenv-reviewer/private-key.pem"
   }
   ```

   Set config mode `600` too. This is a schema example, not a registered App.
   The command rejects missing/invalid IDs and unsafe key permissions, ownership,
   symlinks and unreadable keys. PEM ignore rules are a guard against accidents,
   not permission to store credentials in a checkout.

Before and after real acceptance, run `gh auth status` and `gh api user --jq .login`
using the normal human environment. Do not change `gh` authentication. The reviewer
does not invoke `gh`, read its credentials, set `GH_TOKEN`, or write its configuration.

## Submit a completed review

Dependencies: Python 3 and OpenSSL, installed by the thin-client Ubuntu package adapter.
The core VM package list is unchanged; reviewer provisioning and private-key
distribution to exe.dev VMs are outside this PR's scope.
No third-party Python packages or network access are needed for the test suite.

Review the code first and record its full head SHA. Save the actual findings in a
UTF-8 file; then submit using the exact model/profile, effort and harness used:

```bash
just submit-agent-review \
  --repo CENorthrup/devenv --pr 123 --event COMMENT \
  --body-file /tmp/review.md \
  --model 'ACTUAL MODEL/PROFILE' --effort 'ACTUAL EFFORT' \
  --harness 'ACTUAL HARNESS' --head-sha FULL_40_CHARACTER_REVIEWED_SHA
```

The uppercase example values must be replaced by real review metadata. The tool
requires caller-supplied values; it cannot infer or attest which model reasoned
about the code. From outside the checkout use its absolute
`scripts/submit-agent-review.sh` path via `bash`. Use `--config /absolute/path` to
select a different local config. Repository scope is explicitly limited to
`CENorthrup/devenv`; adding repositories requires a deliberate future change.

Optional `--comments-file /tmp/findings.json` attaches inline findings to the same
review. This is a JSON array using GitHub's diff coordinates:

```json
[
  {"path": "scripts/example.sh", "line": 10, "side": "RIGHT", "body": "Explain the finding and its impact."}
]
```

For a multiline finding include `start_line` and `start_side`. GitHub validates
whether the location belongs to the reviewed diff. `LEFT` refers to removed code,
`RIGHT` to added/current code. No unrelated issue comments are posted.

Every body gets this stable, generated block:

```text
Agent review provenance

Role: reviewer
Model: <caller-provided exact model/profile>
Effort: <caller-provided effort>
Harness: <caller-provided harness>
Reviewed commit: <full reviewed SHA>
```

The App signs an RS256 JWT, verifies its own slug and the configured installation,
and mints a short-lived token limited to this repository and PR write permission.
Credentials exist only in process memory and pipes; signing reads the original
restricted key through an open file descriptor. No credential temp files are
created, on either success or failure. API redirects are refused.

All events check the live PR head immediately before submission and send explicit
`commit_id`. A stale SHA fails and requires another review. GitHub does not offer
an atomic compare-and-submit operation: a push racing this last check can still
occur, but the review stays bound to the explicitly reviewed commit, never the
newer one. Human merge decisions must use reviews of the current head.

`COMMENT` means no explicit blocking/approval decision is appropriate.
`REQUEST_CHANGES` means findings should block merge. `APPROVE` means an independent
review found no remaining blockers for that exact revision. Passing tests alone
is not a review, and a new commit does not automatically clear blocking findings.

## Rotation and diagnosis

Generate another key in the same App's settings. Replace the local PEM atomically
with the new file, keeping ownership and mode `600`; then validate it with a real,
justified review and revoke the old key in GitHub. Revoke a compromised key
immediately. Keep downloads and backups out of repositories; delete obsolete
local copies deliberately. No installation tokens are stored to rotate locally.

For failures, check local config, key ownership/mode, RSA PEM format and OpenSSL.
For HTTP 401 check the App ID/key pairing and system clock. For 403/404 check
installation ID, selected repository access, suspension and PR write permission.
For 422 check inline diff locations, event and review body. API errors suppress
raw response bodies to avoid exposing credentials. On transport failures or an
unexpected response after POST, inspect the PR before retrying: GitHub may have
accepted the review. The tool never retries a review automatically.

Verify installation scope at <https://github.com/settings/installations>: the
reviewer installation must show **Only select repositories: devenv**, not all
repositories. The command verifies selected-repository installation mode and
restricts each minted token to `devenv`; the settings page is the audit for other
repositories deliberately or accidentally added to the installation itself.

## Validation and acceptance status

Run `just test-agent-review` offline. The tests generate disposable RSA keys in
temporary directories, mock GitHub, and exercise events, provenance, signing,
stale heads, permission/identity failures, secret-safe errors and human auth
preservation. The existing skills, thin-tools and dotfiles tests remain relevant.

Real acceptance is **pending registration/installation and real reviews**:

1. Record the normal human `gh` identity without copying tokens into evidence.
2. Have an independent reviewer examine a real PR and record the model/profile,
   effort, harness and full head SHA.
3. Submit its justified review through the command. Verify the author is
   `devenv-reviewer[bot]`, the generated provenance is accurate, and `commit_id`
   matches the reviewed SHA. Save only the review URL and nonsecret evidence.
4. Establish a real non-`COMMENT` event (`APPROVE` or `REQUEST_CHANGES`) justified
   by that independent review. A test approval of unreviewed code is prohibited.
5. Verify the normal human identity again. Record acceptance evidence here in a
   follow-up commit; do not call this complete before both real identity and
   non-`COMMENT` validation pass.

### PR #8 follow-up validation — 2026-09-22

Validated the existing PR worktree based on `54d3c9d`, with the thin dependency
documentation correction and core package additions removed. The core package
list now matches approved master; no existing core bootstrap requirement was
found for adding these reviewer-only prerequisites. Dotfiles input was clean at
`c0b6febc5bcd6d7863c10c8e3cf7c2538ae095f3`.

- `sudo bash wsl/test-fresh-ubuntu.sh /home/cenorthrup/projects/dotfiles`
  could not start: `sudo: A terminal is required to authenticate`.
- Running the same script through WSL's root launcher installed Python 3 and
  OpenSSL, but exited 1 in the existing shell/editor checks. The noninteractive
  terminal environment was consistent with Prezto disabling highlighting for
  `TERM=dumb`, while those checks require its highlighting function.
- Repeating with an explicit terminal type exited **0**:

  ```bash
  /mnt/c/Windows/System32/wsl.exe -d Ubuntu -u root -- \
    env TERM=xterm-256color bash /tmp/devenv-pr25-reviewer/wsl/test-fresh-ubuntu.sh \
    /home/cenorthrup/projects/dotfiles
  ```

  Ubuntu Base 26.04.1 checksum verification passed. The unmodified test finished:
  `PASS: missing-dotfiles resume, native tools, fresh PATH, no Node/auth, and byte/mtime-stable rerun.`
  Local logs: `/tmp/devenv-pr8-fresh-ubuntu.log`,
  `/tmp/devenv-pr8-fresh-ubuntu-root.log`, and
  `/tmp/devenv-pr8-fresh-ubuntu-terminal.log` respectively. The temporary root
  filesystems were cleaned by the test; no host packages were changed.
- `tests/agent-review.sh` (9 tests), `tests/agent-skills.sh`,
  `tests/thin-tools.sh`, and `tests/dotfiles-permissions.sh` all passed.
  Package-adapter and fresh-Ubuntu shell syntax checks and `git diff --check`
  passed as well.

Live App acceptance is still blocked: the local reviewer config is absent, and
the real App ID, installation ID and private-key path have not been supplied.
No bot review or approval was manufactured. Keep PR #8 draft until an independent
reviewer completes the real identity/provenance and justified non-`COMMENT`
validation described above.

GitHub references: [App registration](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app),
[App JWTs](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app),
[installation tokens](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app),
[review API](https://docs.github.com/en/rest/pulls/reviews).
