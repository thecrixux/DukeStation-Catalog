# DukeStation Catalog

Public catalog that DukeStation reads to offer texture packs for the games in your library.
The app looks up the game by its PS1 serial and, if a pack is listed for it, shows a download button.

`textures-catalog.json` is the file the app reads:

```
https://raw.githubusercontent.com/thecrixux/DukeStation-Catalog/main/textures-catalog.json
```

## Adding a pack

The pack must be a ZIP with a **direct HTTPS download link** (a GitHub release asset, a file in this
repository, your own server). Links to Mega, Google Drive pages or forum threads do not work because the app
cannot download from them.

```powershell
.\Add-TexturePack.ps1 -Id some-game-hd -Name "Some Game HD" -GameTitle "Some Game" `
    -Serials SLUS-00001 -Version 1.0 -Authors "Author name" `
    -Url https://github.com/author/repo/releases/download/v1.0/pack.zip `
    -SourceUrl https://github.com/author/repo -License "CC BY-NC 4.0"
```

The script downloads the ZIP, measures its size and SHA-256, counts the texture files and writes the entry.
Running it again with the same `-Id` replaces that entry (use a new `-Version` when the pack is updated).
If the ZIP is already on disk, add `-File .\pack.zip` to skip the download.
Then commit and push `textures-catalog.json`; the app picks it up within a few hours (or with **Reload**).

Only list packs whose author allows redistributing or linking them, and fill in `-Authors`, `-SourceUrl`
and `-License` honestly.

## ZIP layout

PNG, JPG, TGA or BMP files under a folder named after the game serial or a `replacements` folder, the same layout
the app's **Import ZIP** accepts. Archives up to 2 GB per file; bigger packs need to be split into parts
(`parts` in the JSON, see the app's catalog parser).

## The test pack

`packs/test-pack.zip` is a one-pixel pack that changes nothing in the game. It exists only to check the whole
download and install path. Remove it with:

```powershell
$c = Get-Content .\textures-catalog.json -Raw | ConvertFrom-Json
$c.entries = @($c.entries | Where-Object id -ne 'test-pack')
$c | ConvertTo-Json -Depth 8 | Set-Content .\textures-catalog.json -Encoding UTF8
```

and delete `packs/test-pack.zip`.
