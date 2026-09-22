#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CONFIGURATION
# Replace YOUR_USERNAME and YOUR_REPO with your actual GitHub details.
# ==============================================================================
REPO_URL="https://github.com/michaeltylercollums/Cyberdeck-GUI.git"
# Put this near the top of install.sh on GitHub:
if [ -n "${GITHUB_TOKEN:-}" ]; then
    REPO_URL="https://${GITHUB_TOKEN}@github.com/michaeltylercollums/Cyberdeck-GUI.git"
else
    REPO_URL="https://github.com/michaeltylercollums/Cyberdeck-GUI.git"
fi
DOTFILES_DIR="${HOME}/.dotfiles"
TARGET_CONFIG_DIR="${HOME}/.config"
BACKUP_DIR="${HOME}/.config_backups/$(date +%Y%m%d_%H%M%S)"

echo "==> Starting dotfiles setup..."

# ------------------------------------------------------------------------------
# 1. CLONE OR UPDATE REPOSITORY
# ------------------------------------------------------------------------------
if [ ! -d "${DOTFILES_DIR}/.git" ]; then
    echo "--> Cloning dotfiles into ${DOTFILES_DIR}..."
    git clone "${REPO_URL}" "${DOTFILES_DIR}"
else
    echo "--> Existing dotfiles directory found. Pulling latest commits..."
    git -C "${DOTFILES_DIR}" pull --ff-only
fi

# Ensure ~/.config exists
mkdir -p "${TARGET_CONFIG_DIR}"

# ------------------------------------------------------------------------------
# 2. HELPER FUNCTION: SAFE SYMLINKING
# ------------------------------------------------------------------------------
link_item() {
    local src="$1"
    local dest="$2"

    # Case A: Already correctly symlinked
    if [ -L "${dest}" ] && [ "$(readlink "${dest}")" = "${src}" ]; then
        echo "    [OK] $(basename "${dest}") is already correctly linked."
        return 0
    fi

    # Case B: File/folder exists or is a broken symlink -> Backup first
    if [ -e "${dest}" ] || [ -L "${dest}" ]; then
        mkdir -p "${BACKUP_DIR}"
        echo "    [BACKUP] Backing up existing ${dest} -> ${BACKUP_DIR}/"
        mv "${dest}" "${BACKUP_DIR}/"
    fi

    # Ensure parent destination directory exists
    mkdir -p "$(dirname "${dest}")"

    # Case C: Create the symlink
    echo "    [LINK] ${dest} -> ${src}"
    ln -s "${src}" "${dest}"
}

# ------------------------------------------------------------------------------
# 3. LINK EVERYTHING FROM config/ INTO ~/.config/
# ------------------------------------------------------------------------------
SOURCE_CONFIG_DIR="${DOTFILES_DIR}/config"

if [ -d "${SOURCE_CONFIG_DIR}" ]; then
    echo "--> Linking configurations into ${TARGET_CONFIG_DIR}..."
    
    # Enable nullglob so the loop doesn't fail if the folder is empty
    shopt -s nullglob
    for item in "${SOURCE_CONFIG_DIR}"/*; do
        base_name="$(basename "${item}")"

        # Ignore placeholder files
        if [ "${base_name}" = "placeholder.txt" ]; then
            continue
        fi

        link_item "${item}" "${TARGET_CONFIG_DIR}/${base_name}"
    done
    shopt -u nullglob
else
    echo "--> [WARNING] No 'config' directory found in ${DOTFILES_DIR}."
fi

# ------------------------------------------------------------------------------
# 4. ENVIRONMENT & SHELL HOOKS
# ------------------------------------------------------------------------------
# Ensure Starship hook exists in bashrc if Starship is used
if [ -f "${SOURCE_CONFIG_DIR}/starship.toml" ]; then
    BASHRC="${HOME}/.bashrc"
    if [ -f "${BASHRC}" ]; then
        if ! grep -q 'starship init bash' "${BASHRC}"; then
            echo "--> Adding Starship init hook to ~/.bashrc..."
            echo -e '\n# Starship Prompt\neval "$(starship init bash)"' >> "${BASHRC}"
        fi
    fi
fi

echo "==> Dotfiles setup completed successfully!"
