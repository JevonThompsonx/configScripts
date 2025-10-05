#!/bin/bash
# Alacritty theme setup
echo "Setting up Alacritty themes..."
mkdir -p ~/.config/alacritty/themes
if [ ! -d "$HOME/.config/alacritty/themes/alacritty-theme" ]; then
    git clone https://github.com/alacritty/alacritty-theme.git ~/.config/alacritty/themes
else
    echo "Alacritty themes already cloned."
fi

echo "Starting system config cloning"

echo "Logging into GitHub..."

# Authenticate with GitHub using gh cli
if ! gh auth login; then
  echo "Error: Failed to authenticate with GitHub. Exiting."
  exit 1
fi

echo "Authentication successful. Starting to clone repositories..."

# Function to clone a repository and ensure a clean destination
clone_repo() {
  local repo_name="$1"
  local destination_dir="$2"

  # Remove destination directory if it exists
  if [ -d "$destination_dir" ]; then
    echo "Removing existing directory: $destination_dir"
    rm -rf "$destination_dir" || { echo "Error: Failed to remove $destination_dir. Exiting."; exit 1; }
  fi

  # Create the destination directory
  echo "Creating directory: $destination_dir"
  mkdir -p "$destination_dir" || { echo "Error: Failed to create directory $destination_dir. Exiting."; exit 1; }

  # Clone the repository
  echo "Cloning $repo_name into $destination_dir"
  gh repo clone "$repo_name" "$destination_dir" || { echo "Error: Failed to clone $repo_name. Exiting."; exit 1; }
}

# Clone the repositories
rm -rf /home/jevonx/.config/alacritty
clone_repo alacritty ~/.config/alacritty
clone_repo fish ~/.config/fish
clone_repo WPs ~/Pictures/WPs


echo "System config cloning complete!"
exit 0
