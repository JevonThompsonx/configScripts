# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Select latest kernel packages (Consider pkgs.linuxPackages for stability unless needed)
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Boot kernel modules for fixing specific hardware (e.g., Lenovo Yoga 720 mouse)
  # Only include these if necessary for your hardware.
  boot.kernelModules = [
    "i2c_hid_acpi"
    "i2c_hid"
    "osmouse"
  ];

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
  programs.hyprland.enable = true;

  # Hint electron apps to use wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Enable the sddm display manager.
  services.displayManager.sddm = {
    enable = true;
    # Explicitly enable Wayland mode for SDDM itself (safer)
    wayland.enable = true;
  };

  # Configure keymap in X11 (used by XWayland apps)
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false; # Ensure PulseAudio is disabled
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # jack.enable = true; # Uncomment if you need JACK applications
  };

  # Enable touchpad support (libinput) used by Wayland.
  services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd jevon’.
  users.users.jevon = {
    isNormalUser = true;
    description = "Jevon Thompson";
    extraGroups = [ "networkmanager" "wheel" ]; # 'wheel' for sudo access
    packages = with pkgs; [
      # User-specific applications (consider home-manager later)
      kdePackages.kate # Text Editor
      tidal-hifi
      obsidian
      librewolf
      motrix
      tailscale        # Tailscale CLI/service integration
      nextcloud-client

      # User theme preferences (installed system-wide but logically user-specific)
      sweet-nova
      sweet-folders
      candy-icons
    ];
  };

  # Enable the Tailscale service daemon
  services.tailscale.enable = true;

  # Allow unfree packages (needed for tidal-hifi, potentially others)
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile.
  environment.systemPackages = with pkgs; [
    # Essentials
    neovim # Or your preferred CLI editor
    git
    wget
    curl
    unzip
    ripgrep
    fd

    # Hyprland Ecosystem & Utilities
    waybar           # Status bar
    wofi             # Application launcher
    mako             # Notification daemon
    hyprlock         # Screen locker (Hyprland native)
    hypridle         # Idle management daemon (Hyprland native)
    grim             # Screenshot tool (backend)
    slurp            # Screenshot region selection (backend)
    grimblast        # Screenshot helper scripts (uses grim/slurp)
    wl-clipboard     # Wayland clipboard utilities (wl-copy/wl-paste)
    clipman          # Clipboard manager (Wayland)
    brightnessctl    # Brightness control CLI
    pavucontrol      # Volume control GUI (works with Pipewire-Pulse)
    wpaperd          # Wallpaper daemon (Wayland) - needs config
    blueman          # Bluetooth manager GUI + applet backend
    networkmanagerapplet # Provides GUI/applet for NetworkManager
    playerctl        # Control media players via CLI (for media keys)
    polkit_gnome     # Provides authentication agent for graphical actions (needed)
    rofimoji         # Emoji picker for Rofi/Wofi

    # Terminals
    foot             # Lightweight Wayland terminal
    alacritty        # GPU-accelerated Wayland terminal

    # File Manager
    dolphin          # KDE/Qt File Manager

    # System Tools & Utilities
    gh               # GitHub CLI
    zoxide           # Smarter directory navigation
    fastfetch        # System info fetcher
    eza              # Modern 'ls' replacement
    xdg-utils        # For xdg-open and mime types handling

    # Theming & Fonts
    nwg-look         # GTK theme switcher (Wayland compatible)
    bibata-cursors   # Example cursor theme
    # Fonts
    fira-code        # Programming font with ligatures
    inter            # Clean UI font
    noto-fonts       # Standard UI fonts
    noto-fonts-cjk   # Fonts for CJK languages
    noto-fonts-emoji # Emoji support
    font-awesome     # Icon font (often used in waybar)
    (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" ]; }) # Popular icon fonts

    # Compatibility & Libraries
    qt5.qtwayland    # Qt5 Wayland support
    qt6.qtwayland    # Qt6 Wayland support
    libsForQt5.qt5.qtgraphicaleffects # Sometimes needed for Qt themes/effects
    libnotify        # Library for sending desktop notifications (used by notify-send)
    xdg-desktop-portal-gtk # Backend for XDG portals (file picker, etc.)

    # Optional: Basic build tools (can be useful)
    # gcc
    # gnumake

    # Optional: KWallet integration if using Dolphin/KDE apps extensively
    kdePackages.kwalletmanager
    kdePackages.kwallet-pam
  ];

  # Use power-profiles-daemon for power management.
  services.power-profiles-daemon.enable = true;

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

  # This value determines the NixOS release from which the default
  # settings for stateful data were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option.
  # !!! IMPORTANT: Set this to the version you INITIALLY installed NixOS with !!!
  # !!! Do NOT just change it to the latest version number unless you know what you are doing !!!
  system.stateVersion = "24.11"; # Check this value carefully! Example: "23.11", "24.05" etc.

}
