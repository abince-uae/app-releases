# App releases

Download links for our apps. This repo holds no source code, only the release files, attached to [GitHub Releases](../../releases).

## Apps

| App | Download |
|---|---|
| Shuttle Desk | [Android](../../releases/download/shuttle-desk-latest/shuttle-desk.apk) |

Each link always gives the newest version. Every earlier version stays on the [Releases page](../../releases).

## Publishing a version

Needs the [GitHub CLI](https://cli.github.com/), signed in.

```bash
bash publish.sh shuttle-desk 1.2.3 path/to/app.apk "What changed"
```

It prints the app's download link. A version that is already published is refused, so the record can't be overwritten.

## Adding an app

1. Create `apps/<app-name>/app.env`, with the name in lowercase words joined by hyphens:

   ```bash
   NAME="Display Name"
   EXTENSION=apk
   ```

2. Add a row to the table above, linking to `../../releases/download/<app-name>-latest/<app-name>.<extension>`.

## How it works

Each published version makes or updates two releases:

| Release | Holds | Changes? |
|---|---|---|
| `<app>-v1.2.3` | `<app>-1.2.3.apk` | Never |
| `<app>-latest` | `<app>.apk` | Replaced by each new version |

Always link to `<app>-latest`. Don't use GitHub's `/releases/latest/` address: there is only one per repo, so it would point at whichever app published last.

The binaries live in Releases, not in git, so `.gitignore` keeps them out of the repo.

## Tests

```bash
bash tests/publish_test.sh
```

They use a stand-in for the GitHub CLI, so nothing is published.
