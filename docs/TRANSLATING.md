# Translating NCZoningCore

A translation is **one file**, and it ships as its own mod. Nothing has to change in this mod, and you
do not need to wait for a release.

The Core has only **four** strings - the status sentences shown when the location registry cannot be
loaded. The District Guide is where most of the player-facing text lives, and it is translated the
same way.

## What you are editing

Every language already has a slot here, empty, falling through to English:

```text
r6/scripts/NCZoningCore/translations/<Language>.reds
```

Your translation replaces that file. The mod manager hides this mod's copy, so the game compiles yours.

## The three things that must match exactly

Your file has to declare the same path, module and class as the slot it replaces. Get one wrong and
the game will not build - and because redscript compiles every installed mod together, that breaks
every redscript mod the player has, not just this one.

| | Value |
| --- | --- |
| Path | `r6/scripts/NCZoningCore/translations/<Language>.reds` |
| Module | `NCZoning.Translations` |
| Class | `NCZ_<Language>` |

`<Language>` is the slot name, not the language code. The full list is in `translations/Provider.reds`.

## Steps

1. Copy the body of `translations/English.reds`.
2. Translate the **second** argument of each `Text(...)` call. **Never change the key** - the first
   argument. A changed key silently stops resolving and the player sees the key itself.
3. Save it over the slot file for your language, keeping the header's module and class name.
4. Zip it with the folder structure intact, starting at `r6/`.

```text
MyTranslation.zip
└── r6/scripts/NCZoningCore/translations/German.reds
```

That zip installs like any other mod, and should load after this one.

## What you do not have to do

- **You do not have to translate everything.** Anything you leave out falls back to English.
- **You do not have to keep up with updates.** New strings appear in English until someone translates
  them.
- **You do not have to touch `Provider.reds`.** The slot for your language already exists.

## The one placeholder

`{file}` is replaced at runtime with the registry cache filename. Keep it exactly as written and do
not spell the filename out - it is defined in one place in the code, and writing it into a translation
would leave a second copy to go wrong.

## Credit

Send it over and it can go up as an optional file on the mod page, credited to you - or publish it
yourself as a standalone mod. Either works, and neither needs anything from this mod.
