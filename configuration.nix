# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  #select latest kernel packages

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # boot for fixing lenovo yoga 720 12KiB mouse
  boot.kernelModules = [
    "i2c_hid_acpi"
    "i2c_hid"
    "osmouse"
  ];


  networking.hostName = "jevLenovoNixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
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

  # Enable the X11 windowing system.
  # Recommendation: Keep enabled for XWayland compatibility (running X11 apps).
  services.xserver.enable = true;

  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    # Recommendation: Enable the XDG Desktop Portal for Hyprland for better
    # integration (screen sharing, file pickers) with sandboxed apps (Flatpak).
    # The package `xdg-desktop-portal-gtk` is also added to systemPackages below.
    xdg_portal.enable = true;
  };

  # Optional, hint electron apps to use wayland:
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Enable the sddm display manager.
  services.displayManager.sddm.enable = true;
  # services.desktopManager.plasma6.enable = false; # Already disabled, good.

  # Configure keymap in X11 (used by XWayland)
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true; # Wireplumber is default now
  };

  # Enable touchpad support (primarily for X11 sessions, but libinput needed anyway)
  services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.jevon = {
    isNormalUser = true;
    description = "Jevon Thompson";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate

      tidal-hifi
      obsidian
      librewolf
      motrix

      tailscale
      nextcloud-client

      foot       # Wayland terminal
      alacritty  # Wayland terminal
      dolphin    # File manager (already here, removed from systemPackages)
      gh
      zoxide
      fastfetch
      eza

      # sweet theme packages
      sweet-nova
      sweet-folders
      candy-icons
    ];
  };

  # Enable the Tailscale service
  services.tailscale.enable = true;

  # Recommendation: Disable autoLogin initially to ensure you can manually select
  # the Hyprland session in SDDM. Re-enable later if desired.
  # services.xserver.displayManager.autoLogin.enable = true;
  # services.xserver.displayManager.autoLogin.user = "jevon";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Essentials
    neovim # Editor for configuration
    git

    # Hyprland Ecosystem & Utilities
    waybar          # Status bar
    wofi            # Application launcher (Wayland compatible)
    mako            # Notification daemon (Wayland compatible)
    swaylock-effects # Screen locker (Wayland, with effects)
    swayidle        # Idle management daemon (for locking, sleep triggers)
    grim            # Screenshot tool (backend)
    slurp           # Screenshot region selection (backend)
    grimblast       # Screenshot helper scripts (uses grim/slurp)
    wl-clipboard    # Wayland clipboard utilities (wl-copy/wl-paste)
    clipman         # Clipboard manager (Wayland) - CHOOSE ONE (or copyq)
    # copyq         # Alternative clipboard manager - Install only one!
    brightnessctl   # Brightness control CLI
    pavucontrol     # Volume control GUI (works with Pipewire-Pulse)
    wpaperd         # Wallpaper daemon (Wayland)
    blueman         # Bluetooth manager GUI + applet backend
    networkmanagerapplet # Provides GUI/applet for NetworkManager
    playerctl       # Control media players via CLI (for media keys)
    polkit_gnome    # Provides authentication agent for graphical actions
    rofimoji        # Emoji picker

    # Theming & Fonts
    nwg-look        # GTK theme switcher (Wayland compatible)
    bibata-cursors  # Example cursor theme
    fira-code       # Font (already listed)
    inter           # Font (already listed)
    noto-fonts      # Standard UI fonts
    noto-fonts-cjk  # Fonts for CJK languages
    noto-fonts-emoji # Emoji support
    # nerdfonts     # Optional: Fonts with icons (for waybar, terminal prompts)

    # Compatibility & Libraries
    qt5.qtwayland   # Qt5 Wayland support (for Dolphin, etc.)
    qt6.qtwayland   # Qt6 Wayland support
    libnotify       # Library for sending desktop notifications (used by notify-send)
    xdg-desktop-portal-gtk # Needed for file pickers / portals in GTK apps

    # Development / Other Tools (already listed)
    nodejs
    gh              # Already in user packages, can be removed if only for user
    zoxide          # Already in user packages, can be removed if only for user
    fastfetch       # Already in user packages, can be removed if only for user
    eza             # Already in user packages, can be removed if only for user
  ];

  # Recommendation: Prefer power-profiles-daemon over tlp unless tlp is needed
  # for specific hardware quirks not handled by ppd.
  services.power-profiles-daemon.enable = true;
  # programs.tlp.enable = true; # Usually redundant with power-profiles-daemon

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    # Recommendation: Consider security hardening like disabling password auth
    # services.openssh.settings.PasswordAuthentication = false;
    # services.openssh.settings.KbdInteractiveAuthentication = false;
  };


  # Open ports in the firewall.
  # Recommendation: Enable the firewall for basic security.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # Allow SSH
    # allowedUDPPorts = [ ... ];
  };
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

  # Recommendation: Consider using Home Manager to manage user-specific
  # packages, dotfiles (like hyprland.conf, waybar config), and services.
  # It keeps your user environment declarative and version-controlled.

}
