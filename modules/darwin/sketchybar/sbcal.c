// Renders a month calendar to a PNG for SketchyBar's clock popup (popups can
// only stack text rows, so a real grid has to be an image).
//
//   sbcal YEAR MONTH TODAY OUT.png FG DIM FAINT BG LINE
//
// TODAY is the day to circle (0 for none); the colours are 0xAARRGGBB values
// passed in from config/theme.lua, the single source of truth. Prints the
// image height in points. Drawn at 2x on a transparent background (the popup
// paints its own).
#include <ApplicationServices/ApplicationServices.h>
#include <CoreText/CoreText.h>
#include <ImageIO/ImageIO.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define SCALE 2.0
#define W 268.0
#define PAD 14.0
#define TITLE_H 34.0
#define HEAD_H 24.0
#define CELL_H 32.0
#define FONT "JetBrainsMono Nerd Font"

static void rgba(CGContextRef c, uint32_t argb) {
  CGContextSetRGBFillColor(c, ((argb >> 16) & 0xff) / 255.0, ((argb >> 8) & 0xff) / 255.0,
                           (argb & 0xff) / 255.0, ((argb >> 24) & 0xff) / 255.0);
}

// Draw TEXT with its centre at (cx, cy); align -1 left edge at cx, 1 right edge.
static void text(CGContextRef c, const char *s, double size, bool bold, uint32_t argb,
                 double cx, double cy, int align) {
  CTFontRef base = CTFontCreateWithName(CFSTR(FONT), size, NULL);
  CTFontRef font = bold ? CTFontCreateCopyWithSymbolicTraits(base, size, NULL, kCTFontBoldTrait, kCTFontBoldTrait) : NULL;
  if (!font) font = (CTFontRef)CFRetain(base);
  CGColorRef color = CGColorCreateSRGB(((argb >> 16) & 0xff) / 255.0, ((argb >> 8) & 0xff) / 255.0,
                                       (argb & 0xff) / 255.0, ((argb >> 24) & 0xff) / 255.0);
  CFStringRef str = CFStringCreateWithCString(NULL, s, kCFStringEncodingUTF8);
  const void *keys[] = { kCTFontAttributeName, kCTForegroundColorAttributeName };
  const void *vals[] = { font, color };
  CFDictionaryRef attrs = CFDictionaryCreate(NULL, keys, vals, 2, &kCFTypeDictionaryKeyCallBacks,
                                             &kCFTypeDictionaryValueCallBacks);
  CFAttributedStringRef astr = CFAttributedStringCreate(NULL, str, attrs);
  CTLineRef line = CTLineCreateWithAttributedString(astr);
  CGFloat ascent, descent;
  double w = CTLineGetTypographicBounds(line, &ascent, &descent, NULL);
  double x = align < 0 ? cx : (align > 0 ? cx - w : cx - w / 2);
  CGContextSetTextPosition(c, x, cy - (ascent - descent) / 2);
  CTLineDraw(line, c);
  CFRelease(line); CFRelease(astr); CFRelease(attrs); CFRelease(str);
  CGColorRelease(color); CFRelease(font); CFRelease(base);
}

int main(int argc, char **argv) {
  if (argc != 10) {
    fprintf(stderr, "usage: %s YEAR MONTH TODAY OUT.png FG DIM FAINT BG LINE\n", argv[0]);
    return 1;
  }
  int year = atoi(argv[1]), month = atoi(argv[2]), today = atoi(argv[3]);

  struct tm first = { .tm_year = year - 1900, .tm_mon = month - 1, .tm_mday = 1, .tm_hour = 12 };
  mktime(&first);
  struct tm last = { .tm_year = year - 1900, .tm_mon = month, .tm_mday = 0, .tm_hour = 12 };
  mktime(&last);
  struct tm prev = { .tm_year = year - 1900, .tm_mon = month - 1, .tm_mday = 0, .tm_hour = 12 };
  mktime(&prev);
  int days = last.tm_mday, prev_days = prev.tm_mday;
  int offset = (first.tm_wday + 6) % 7;  // Monday first
  int weeks = (offset + days + 6) / 7;

  double h = PAD + TITLE_H + HEAD_H + weeks * CELL_H + PAD / 2;
  size_t pw = (size_t)(W * SCALE), ph = (size_t)(h * SCALE);
  CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
  CGContextRef c = CGBitmapContextCreate(NULL, pw, ph, 8, 0, cs, kCGImageAlphaPremultipliedLast);
  CGContextScaleCTM(c, SCALE, SCALE);
  CGContextSetShouldSmoothFonts(c, false);

  const uint32_t fg = (uint32_t)strtoul(argv[5], NULL, 0), dim = (uint32_t)strtoul(argv[6], NULL, 0),
                 faint = (uint32_t)strtoul(argv[7], NULL, 0), dark = (uint32_t)strtoul(argv[8], NULL, 0),
                 line = (uint32_t)strtoul(argv[9], NULL, 0);
  double cw = (W - 2 * PAD) / 7.0;
  double top = h - PAD;  // CoreGraphics' origin is bottom-left

  // Title: "November" bold + year dim
  char title[64];
  strftime(title, sizeof title, "%B", &first);
  text(c, title, 15, true, fg, PAD + 2, top - TITLE_H / 2 + 2, -1);
  char yr[8];
  snprintf(yr, sizeof yr, "%d", year);
  text(c, yr, 15, false, dim, W - PAD - 2, top - TITLE_H / 2 + 2, 1);

  // Weekday header and a hairline under it
  const char *names[] = { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" };
  double hy = top - TITLE_H - HEAD_H / 2;
  for (int i = 0; i < 7; i++)
    text(c, names[i], 11, true, i >= 5 ? faint : dim, PAD + cw * (i + 0.5), hy, 0);
  rgba(c, line);
  CGContextFillRect(c, CGRectMake(PAD, top - TITLE_H - HEAD_H, W - 2 * PAD, 1));

  // Days; neighbouring months fill the grid in a faint tone
  for (int cell = 0; cell < weeks * 7; cell++) {
    int col = cell % 7, row = cell / 7;
    int day = cell - offset + 1;
    bool inside = day >= 1 && day <= days;
    int shown = inside ? day : (day < 1 ? prev_days + day : day - days);
    double cx = PAD + cw * (col + 0.5);
    double cy = top - TITLE_H - HEAD_H - CELL_H * (row + 0.5);
    char num[4];
    snprintf(num, sizeof num, "%d", shown);
    if (inside && day == today) {
      rgba(c, fg);
      CGContextFillEllipseInRect(c, CGRectMake(cx - 13, cy - 13, 26, 26));
      text(c, num, 13, true, dark, cx, cy, 0);
    } else {
      text(c, num, 13, false, !inside ? faint : (col >= 5 ? dim : fg), cx, cy, 0);
    }
  }

  CGImageRef img = CGBitmapContextCreateImage(c);
  CFStringRef path = CFStringCreateWithCString(NULL, argv[4], kCFStringEncodingUTF8);
  CFURLRef url = CFURLCreateWithFileSystemPath(NULL, path, kCFURLPOSIXPathStyle, false);
  CGImageDestinationRef dest = CGImageDestinationCreateWithURL(url, CFSTR("public.png"), 1, NULL);
  if (!dest) return 1;
  CGImageDestinationAddImage(dest, img, NULL);
  bool ok = CGImageDestinationFinalize(dest);
  CFRelease(dest); CFRelease(url); CFRelease(path); CGImageRelease(img);
  CGContextRelease(c); CGColorSpaceRelease(cs);
  if (!ok) return 1;
  printf("%.0f\n", h);
  return 0;
}
