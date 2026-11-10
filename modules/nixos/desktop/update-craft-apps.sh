#!/usr/bin/env bash
# bump the storytold AppImages in craft-apps.nix to the latest GitHub release.
# run from the dotfiles root: nix run .#update-craft-apps
# or pass the file:        update-craft-apps path/to/craft-apps.nix
set -euo pipefail

file=${1:-modules/nixos/desktop/craft-apps.nix}
[ -f "$file" ] || {
	echo "no such file: $file" >&2
	exit 1
}

apps=(photocraft vectorcraft wordcraft gridcraft pdfcraft deckcraft soundcraft effectcraft figcraft filmcraft)

for app in "${apps[@]}"; do
	release=$(curl -fsSL "https://api.github.com/repos/storytold/$app/releases/latest")
	version=$(jq -r '.tag_name | sub("^v"; "")' <<<"$release")

	read -r asset digest < <(
		jq -r '.assets[] | select(.name | endswith("-linux-x86_64.AppImage")) | "\(.name) \(.digest)"' \
			<<<"$release" | head -n1
	)

	if [ -z "${asset:-}" ] || [ -z "${digest:-}" ] || [ "$digest" = "null" ]; then
		echo "$app: no linux-x86_64 AppImage with a digest in the latest release" >&2
		exit 1
	fi

	hash=$(nix hash convert --hash-algo sha256 --to sri "${digest#sha256:}")

	APP=$app VERSION=$version HASH=$hash perl -0pi -e '
		s/(pname = "\Q$ENV{APP}\E";\n\s*version = ")[^"]+("\s*;\n\s*hash = ")[^"]+(")/$1$ENV{VERSION}$2$ENV{HASH}$3/
	' "$file"

	echo "$app $version"
done
