# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Consider using pkgs.linuxPackages (stable) unless _latest is specifically needed
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Boot kernel modules for fixing specific hardware (e.g., Lenovo Yoga 720 mouse)
  # Check if these are truly needed beyond what hardware-configuration.nix provides.
  boot.kernelModules = [
    "i2c_hid_acpi"
    "i2c_hid"
    "osmouse" # Often less relevant now, test if needed
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "jevLenovoNixos"; # Define your hostname.

  # Enable networking & NetworkManager Applet support
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system for XWayland compatibility. Recommended.
  services.xserver.enable = true;

  # Enable Hyprland Wayland compositor
  programs.hyprland = {
    enable = true;
    # package = pkgs.hyprland; # Default
    # Optionally enable XWayland HiDPI support if needed (usually automatic)
   xwayland.enable = true;
  };

  # === Essential Wayland / Hyprland Settings ===
  # Enable PipeWire for audio
  hardware.pulseaudio.enable = false; # Ensure PulseAudio is disabled
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # jack.enable = true; # Uncomment if you need JACK applications
  };

  # Enable touchpad support via libinput (used by Wayland compositors)
  services.libinput.enable = true; # Changed from services.xserver.libinput.enable for clarity

  # XDG Desktop Portal setup (CRUCIAL for Wayland integration)
  xdg.portal = {
    enable = true;
    # Default backend: GTK (already installed via systemPackages)
    # Extra backends: Hyprland is essential, KDE useful for Qt apps
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-kde
      # xdg-desktop-portal-gtk # Already added implicitly via systemPackages below if needed
    ];
    # Optional: Explicitly set default portals if needed, usually auto-detected
    # config.common.default = "*"; # Or specify like ["hyprland" "gtk"]
  };

  # Use power-profiles-daemon for power management.
  services.power-profiles-daemon.enable = true;

  # Enable Bluetooth service
  services.bluetooth.enable = true; # Enables the core bluetooth service
  services.blueman.enable = true;  # Enables the Blueman Applet service

  # Hint electron apps to use wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Font configuration
  fonts.fontconfig.enable = true;

  # === Display Manager ===
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true; # Run SDDM itself in Wayland mode
    # theme = "your-sddm-theme"; # Optionally set SDDM theme
  };

  # Configure keymap in X11 (used by XWayland apps)
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # === User Account ===
  # Consider using Home Manager (https://nix-community.github.io/home-manager/)
  # for managing user packages and dotfiles separately.
  users.users.jevon = {
    isNormalUser = true;
    description = "Jevon Thompson";
    extraGroups = [ "networkmanager" "wheel" "audio" "video" "input" ]; # Added common groups
    packages = with pkgs; [
      # User-specific applications (consider moving to home-manager)
      kdePackages.kate # Text Editor
      tidal-hifi
      obsidian
      librewolf
      motrix
      # tailscale # Installed system-wide, CLI usable by user
      nextcloud-client

      # User theme preferences (installed system-wide but logically user-specific)
      # These packages only provide the themes; applying them is done elsewhere
      # (e.g., Hyprland config, nwg-look, qt5ct/kvantum)
      sweet-nova
      sweet-folders
      candy-icons
    ];
  };

  # Enable the Tailscale service daemon
  services.tailscale.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # === System Packages ===
  environment.systemPackages = with pkgs; [
    # --- Essentials ---
    neovim
    git
    wget
    curl
    unzip
    ripgrep # Fast search tool
    fd      # Fast find alternative

    # --- Hyprland Ecosystem & Wayland Utilities ---
    waybar              # Status bar
    wofi                # Application launcher
    mako                # Notification daemon
    hyprlock            # Screen locker (Hyprland native)
    hypridle            # Idle management daemon (Hyprland native)
    grim                # Screenshot tool (backend)
    slurp               # Screenshot region selection (backend)
    grimblast           # Screenshot helper scripts (uses grim/slurp)
    wl-clipboard        # Wayland clipboard utilities (wl-copy/wl-paste)
    clipman             # Clipboard manager (Wayland - requires setup in Hyprland config)
    brightnessctl       # Brightness control CLI
    pavucontrol         # Volume control GUI (works with Pipewire-Pulse)
    wpaperd             # Wallpaper daemon (Wayland - needs config)
    blueman             # Bluetooth manager GUI + applet backend (service enabled above)
    networkmanagerapplet # Provides GUI/applet for NetworkManager (service enabled above)
    playerctl           # Control media players via CLI (for media keys)
    polkit_gnome        # Provides authentication agent for graphical actions (needed by Hyprland)
    rofimoji            # Emoji picker for Rofi/Wofi

    # --- Terminals ---
    foot                # Lightweight Wayland terminal
      alacritty         # GPU-accelerated Wayland terminal (pick one or have both)

    # --- File Manager ---
    dolphin             # KDE/Qt File Manager

    # --- System Tools & Utilities ---
    gh                  # GitHub CLI
    zoxide              # Smarter directory navigation
    fastfetch           # System info fetcher
    eza                 # Modern 'ls' replacement
    xdg-utils           # For xdg-open and mime types handling
    tailscale           # Installs the CLI tool (service enabled above)
    killall             # Utility to kill processes by name

    # --- Theming & Fonts ---
    nwg-look            # GTK theme switcher (Wayland compatible)
    qt5ct               # Configuration tool for Qt5 applications styling
    qt6ct               # Configuration tool for Qt6 applications styling
    kvantum             # SVG-based theme engine for Qt applications
    bibata-cursors      # Example cursor theme
    # Fonts (ensure you have fonts needed by Waybar, etc.)
    fira-code           # Programming font with ligatures
    inter               # Clean UI font
    noto-fonts          # Standard UI fonts
    noto-fonts-cjk-sans # Optional: For CJK character support
    noto-fonts-emoji    # Emoji support
    font-awesome        # Icon font (often used in waybar)
    jetbrains-mono      # Popular programming font
    (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" "FontAwesome" ]; }) # Popular icon fonts

    # --- Compatibility & Libraries ---
    qt5.qtwayland       # Qt5 Wayland support
    qt6.qtwayland       # Qt6 Wayland support
    libsForQt5.qt5.qtgraphicaleffects # Sometimes needed for Qt themes/effects
    libnotify           # Library for sending desktop notifications (used by notify-send and mako)
    # XDG Desktop Portal Backends (Ensure these align with xdg.portal.extraPortals)
    xdg-desktop-portal-gtk

    # --- Hardware Acceleration (Intel) ---
    intel-media-driver  # VAAPI driver for Intel hardware video acceleration
    # vulkan-tools      # Optional: For checking Vulkan support (vkinfo)
    # intel-gpu-tools   # Optional: For Intel GPU diagnostics

    # --- Optional: Basic build tools ---
    # gcc
    # gnumake

    # --- Optional: KWallet integration ---
    # kdePackages.kwalletmanager
    # kdePackages.kwallet-pam
  ];

  # === Security ===
  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    # Consider security hardening:
    # settings.PasswordAuthentication = false;
    # settings.KbdInteractiveAuthentication = false;
  };

  # Configure firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # Allow SSH
    # allowedUDPPorts = [ ... ];
  };

  # === System State ===
  # This value determines the NixOS release from which the default
  # settings for stateful data were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option.
  # !!! IMPORTANT: Set this to the version you INITIALLY installed NixOS with !!!
  # !!! Or the version you consciously migrated state to. Check carefully! !!!
  system.stateVersion = "24.11"; # Example: "23.11", "24.05". Verify this value!

}
