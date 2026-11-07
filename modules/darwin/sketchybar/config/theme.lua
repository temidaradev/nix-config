-- Breeze Dark, as on the Linux bar (quickshell/Theme.qml), kept monochrome:
-- icons are white or grey, amber/red are reserved for warnings. Colors are 0xAARRGGBB.
return {
  bg          = 0xff1b1e20, -- opaque: it covers Apple's menu bar underneath
  popup       = 0xff1f2224,
  surface     = 0xff272c30, -- quiet grouping behind telemetry and battery
  fg          = 0xffe8ecef,
  dim         = 0xffa4adb5,
  faint       = 0xff737d86,
  red         = 0xffda4453,
  amber       = 0xfff6c744,
  nix         = 0xff7ebae4, -- the one splash of colour: NixOS blue
  hover       = 0x18ffffff,
  border      = 0x1affffff,
  transparent = 0x00000000,

  font        = "JetBrainsMono Nerd Font",
  size        = 13.0,
  small       = 12.0,
  glyph       = 15.0,
  -- Compact external bar; match Apple's taller bar only on notched displays.
  height      = 28,
  notch_height = 39,
  pill        = 24,
  radius      = 7,
}
