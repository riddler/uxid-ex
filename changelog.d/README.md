# Changelog fragments

Changelog entries for unreleased work live here as one file per issue, not as
edits to `CHANGELOG.md`. At release the fragments are assembled into a single
version section and deleted.

## Why fragments

Parallel work happens in one worktree per issue, so several branches are
usually open at once. If each branch appended to the top of `CHANGELOG.md`,
every branch would touch the same few lines of the same file and nearly every
pull request would conflict with every other one.

A fragment is named after its issue, so no two branches ever write the same
file and the conflict cannot happen.

## When a change needs a fragment

The changelog serves **people who use the library**. Repo history is git's job,
and work tracking is beads' job. Neither belongs here.

Write a fragment for:

- a public API addition, change, or removal
- a change in observable behavior
- a bug fix a user could have noticed
- anything breaking

Do **not** write a fragment for:

- test harness or fixtures
- documentation or plans
- internal refactors with no visible effect
- quality gate, CI, or agent tooling changes

If you are unsure, ask whether someone who only ever calls the public API could
tell the difference. If not, skip it.

## Format

One file per issue, named for the beads issue ID:

    changelog.d/ux-abc.md

Contents are the Keep a Changelog section heading followed by the entry:

```markdown
### Added

- A registry key can declare its own size, so every call site and Ecto field
  that mints it gets the same shape without repeating the option.
```

Rules:

- Use only the standard headings: `Added`, `Changed`, `Deprecated`, `Removed`,
  `Fixed`, `Security`, plus a bold `**Breaking**` for a breaking change.
- A breaking change goes under `### **Breaking**`, and that heading comes
  first in a section, ahead of `Added`.
- One line per change, present tense, describing the effect on the user.
- No nested bullets. Detail belongs in the pull request and the commit body; a
  changelog line that needs sub-points is really several changes or one that is
  over-explained.
- One file may carry more than one heading if an issue genuinely spans them.
- For a breaking change, say what to do about it, not just what broke.
- A fragment marked `**Breaking**` keeps that heading when it is promoted at
  release. It is not folded into `Changed` or `Removed`, and the bold marker
  is not dropped.
- Examples stay domain-free: neutral resource prefixes such as `usr` or `cus`.

## At release

Assemble the fragments into a new version section in `CHANGELOG.md`. The
section keeps this file's own heading shape, `## X.Y.Z / YYYY-MM-DD`, and
groups the entries inside it under the Keep a Changelog subheadings, ordered
`**Breaking**`, `Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`,
`Security`. A `**Breaking**` fragment carries its heading through the
promotion unchanged, so the version section opens with `### **Breaking**` and
keeps the sentence saying what to do about the change. The sections already
in `CHANGELOG.md` are not rewritten. Delete the fragments in the same commit
that cuts the release.

Tagging is a separate step after that commit merges: the release prep - the
version bump, the promoted `CHANGELOG.md` section, the README's version pin,
the deleted fragments - merges on its own, then its merged commit is tagged
and the release workflow publishes on the tag push (CLAUDE.md, "Release
preps"). Because the prep consumes every fragment its siblings wrote, it
merges LAST on its lane: a branch still holding an unmerged fragment when the
prep lands misses that release and has to wait for the next one.
