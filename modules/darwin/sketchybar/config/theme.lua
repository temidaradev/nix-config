-- Breeze Dark, as on the Linux bar (quickshell/Theme.qml), kept monochrome:
-- icons are white or grey, amber/red are reserved for warnings. Colors are 0xAARRGGBB.
return {
  bg          = 0xff1b1e20, -- opaque: it covers Apple's menu bar underneath
  popup       = 0xff1f2224,
  fg          = 0xfffcfcfc,
  dim         = 0xffa9aeb3,
  faint       = 0xff6e7378,
  red         = 0xffda4453,
  amber       = 0xfff6c744,
  nix         = 0xff7ebae4, -- the one splash of colour: NixOS blue
  hover       = 0x24ffffff,
  border      = 0x26ffffff,
  transparent = 0x00000000,

  font        = "JetBrainsMono Nerd Font",
  size        = 13.0,
  small       = 12.0,
  glyph       = 15.0,
  -- 39pt is the menu bar height on the notched built-in display; matching it
  -- covers Apple's bar exactly.
  height      = 39,
  pill        = 28,
  radius      = 6,
}
