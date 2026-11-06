// Menu bar bridge for SketchyBar. Uses the public Accessibility API plus
// AppKit (via the ObjC runtime); SkyLight is only dlopen'd for the
// "reveal the hidden menu bar invisibly" trick, so nothing links a private
// framework.
//
//   sbmenus -l            titles of the front app's menus (app menu first)
//   sbmenus -s N          open the front app's menu N (0 = Apple menu)
//   sbmenus -t            third-party menu bar icons: pid<TAB>app<TAB>bundle id
//   sbmenus -x PID        click that app's menu bar icon
//   sbmenus -i ID         click an Apple menu extra (com.apple.menuextra.*)
//   sbmenus -d            displays: CGDirectDisplayID<TAB>builtin(0/1)<TAB>active(0/1)<TAB>width
//                         (active = the one showing the menu bar of the front app)
//   sbmenus -k            switch to the next enabled keyboard layout
//   sbmenus --prompt      ask macOS for Accessibility permission
//
// Since macOS 26 every menu bar icon is drawn by MenuBarAgent; each icon is
// an AX element that still belongs to (has the pid of) the app that owns it.
#include <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h>
#include <dlfcn.h>
#include <libproc.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static CFArrayRef copy_children(AXUIElementRef el) {
  CFArrayRef kids = NULL;
  if (AXUIElementCopyAttributeValue(el, kAXChildrenAttribute, (CFTypeRef *)&kids) != kAXErrorSuccess) return NULL;
  return kids;
}

static bool copy_string(AXUIElementRef el, CFStringRef attr, char *buf, size_t n) {
  CFTypeRef v = NULL;
  buf[0] = 0;
  bool ok = AXUIElementCopyAttributeValue(el, attr, &v) == kAXErrorSuccess && v &&
            CFGetTypeID(v) == CFStringGetTypeID() &&
            CFStringGetCString(v, buf, n, kCFStringEncodingUTF8);
  if (v) CFRelease(v);
  return ok;
}

static pid_t front_pid(void) {
  Class ws_class = objc_getClass("NSWorkspace");
  if (!ws_class) return 0;
  id ws = ((id (*)(Class, SEL))objc_msgSend)(ws_class, sel_registerName("sharedWorkspace"));
  id app = ((id (*)(id, SEL))objc_msgSend)(ws, sel_registerName("frontmostApplication"));
  if (!app) return 0;
  return ((pid_t (*)(id, SEL))objc_msgSend)(app, sel_registerName("processIdentifier"));
}

static pid_t pid_named(const char *name) {
  int n = proc_listallpids(NULL, 0);
  if (n <= 0) return 0;
  pid_t *pids = calloc(n * 2, sizeof(pid_t));
  n = proc_listallpids(pids, n * 2 * sizeof(pid_t));
  pid_t found = 0;
  for (int i = 0; i < n && !found; i++) {
    char buf[256];
    if (pids[i] > 0 && proc_name(pids[i], buf, sizeof buf) > 0 && strcmp(buf, name) == 0) found = pids[i];
  }
  free(pids);
  return found;
}

// Name and bundle id of the outermost .app the process lives in, so helper
// processes inside an app (login items, agents) report the app itself:
// /Applications/Mullvad VPN.app/Contents/... -> "Mullvad VPN", net.mullvad.vpn
static void app_info(pid_t pid, char *name, size_t n, char *bundle, size_t bn) {
  char path[PROC_PIDPATHINFO_MAXSIZE];
  name[0] = bundle[0] = 0;
  if (proc_pidpath(pid, path, sizeof path) <= 0) return;
  char *end = strstr(path, ".app/");
  if (!end) {
    proc_name(pid, name, (uint32_t)n);
    return;
  }
  end[4] = 0;  // keep ".app"
  Class str = objc_getClass("NSString");
  id spath = ((id (*)(Class, SEL, const char *))objc_msgSend)(str, sel_registerName("stringWithUTF8String:"), path);
  id b = ((id (*)(Class, SEL, id))objc_msgSend)(objc_getClass("NSBundle"), sel_registerName("bundleWithPath:"), spath);
  id bid = b ? ((id (*)(id, SEL))objc_msgSend)(b, sel_registerName("bundleIdentifier")) : NULL;
  const char *c = bid ? ((const char *(*)(id, SEL))objc_msgSend)(bid, sel_registerName("UTF8String")) : NULL;
  if (c) snprintf(bundle, bn, "%s", c);
  end[0] = 0;  // drop ".app"
  char *slash = strrchr(path, '/');
  snprintf(name, n, "%s", slash ? slash + 1 : path);
}

typedef int (*cid_fn)(void);
typedef void (*vis_fn)(int, int, bool);
typedef void (*alpha_fn)(int, double, double, float);

// Icons only open their menus while the menu bar is shown, so show it fully
// transparent for the click; SketchyBar stays the only visible bar.
// SketchyBar reports a click on mouse-down. Opening a menu or panel right
// then lets the mouse-up land outside it, and panels like Notification
// Center close on that. Wait (up to 1.5 s) until the buttons are released.
static void wait_for_mouse_up(void) {
  for (int i = 0; i < 150; i++) {
    if (!CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonLeft) &&
        !CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonRight))
      break;
    usleep(10000);
  }
  usleep(30000);
}

static void press(AXUIElementRef item, bool reveal_bar) {
  wait_for_mouse_up();
  void *sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY);
  cid_fn cid = sky ? (cid_fn)dlsym(sky, "SLSMainConnectionID") : NULL;
  vis_fn vis = sky ? (vis_fn)dlsym(sky, "SLSSetMenuBarVisibilityOverrideOnDisplay") : NULL;
  alpha_fn alpha = sky ? (alpha_fn)dlsym(sky, "SLSSetMenuBarInsetAndAlpha") : NULL;
  bool override = reveal_bar && cid && vis && alpha;
  if (override) { int c = cid(); alpha(c, 0, 1, 0.0); vis(c, 0, true); alpha(c, 0, 1, 0.0); usleep(50000); }
  // Press only: an extra AXCancel first toggles some items (the clock's
  // Notification Center opened and closed again).
  AXUIElementPerformAction(item, kAXPressAction);
  if (override) { int c = cid(); vis(c, 0, false); alpha(c, 0, 1, 1.0); }
}

typedef bool (*visit_fn)(AXUIElementRef item, pid_t owner, const char *ident, void *ctx);

// Visit every icon in MenuBarAgent's first menu bar window that has any
// (MenuBarAgent keeps one window per display; the first is the main one).
static void each_icon(visit_fn visit, void *ctx) {
  pid_t agent = pid_named("MenuBarAgent");
  if (!agent) return;
  AXUIElementRef app = AXUIElementCreateApplication(agent);
  AXUIElementSetMessagingTimeout(app, 1.0);
  CFArrayRef wins = copy_children(app);
  bool stop = false;
  for (CFIndex w = 0; wins && w < CFArrayGetCount(wins) && !stop; w++) {
    CFArrayRef groups = copy_children((AXUIElementRef)CFArrayGetValueAtIndex(wins, w));
    CFIndex count = groups ? CFArrayGetCount(groups) : 0;
    for (CFIndex g = 0; g < count && !stop; g++) {
      // Apple extras are group > group > item, third-party ones group > item.
      AXUIElementRef el = (AXUIElementRef)CFRetain(CFArrayGetValueAtIndex(groups, g));
      for (int depth = 0; depth < 3 && el && !stop; depth++) {
        CFArrayRef kids = copy_children(el);
        CFRelease(el);
        el = NULL;
        if (!kids || CFArrayGetCount(kids) == 0) { if (kids) CFRelease(kids); break; }
        el = (AXUIElementRef)CFRetain(CFArrayGetValueAtIndex(kids, 0));
        CFRelease(kids);
        char role[64];
        copy_string(el, kAXRoleAttribute, role, sizeof role);
        if (strcmp(role, "AXButton") == 0 || strcmp(role, "AXMenuBarItem") == 0) {
          pid_t owner = 0;
          AXUIElementGetPid(el, &owner);
          char ident[256];
          copy_string(el, kAXIdentifierAttribute, ident, sizeof ident);
          stop = visit(el, owner == agent ? 0 : owner, ident, ctx);
          break;
        }
      }
      if (el) CFRelease(el);
    }
    if (groups) CFRelease(groups);
    if (count > 0) break;  // only the first window that has icons
  }
  if (wins) CFRelease(wins);
  CFRelease(app);
}

static bool print_icon(AXUIElementRef item, pid_t owner, const char *ident, void *ctx) {
  (void)item; (void)ident; (void)ctx;
  if (!owner) return false;  // Apple's own extras: the bar has its own widgets
  char name[256], bundle[256];
  app_info(owner, name, sizeof name, bundle, sizeof bundle);
  printf("%d\t%s\t%s\n", owner, name, bundle);
  return false;
}

struct match { pid_t pid; const char *ident; };

static bool press_match(AXUIElementRef item, pid_t owner, const char *ident, void *ctx) {
  struct match *m = ctx;
  if ((m->pid && owner == m->pid) || (m->ident && strcmp(ident, m->ident) == 0)) {
    press(item, true);
    return true;
  }
  return false;
}

static void front_menus(long select) {
  pid_t pid = front_pid();
  if (!pid) return;
  AXUIElementRef app = AXUIElementCreateApplication(pid);
  AXUIElementSetMessagingTimeout(app, 1.0);
  CFTypeRef bar = NULL;
  if (AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute, &bar) == kAXErrorSuccess && bar) {
    CFArrayRef kids = copy_children((AXUIElementRef)bar);
    CFIndex count = kids ? CFArrayGetCount(kids) : 0;
    if (select < 0) {
      for (CFIndex i = 1; i < count; i++) {
        char title[512];
        copy_string((AXUIElementRef)CFArrayGetValueAtIndex(kids, i), kAXTitleAttribute, title, sizeof title);
        puts(title);
      }
    } else if (select < count) {
      press((AXUIElementRef)CFArrayGetValueAtIndex(kids, select), false);
    }
    if (kids) CFRelease(kids);
    CFRelease(bar);
  }
  CFRelease(app);
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: %s -l | -s N | -t | -x PID | -i ID | -d | -k | --prompt\n", argv[0]);
    return 1;
  }
  if (strcmp(argv[1], "--prompt") == 0) {
    const void *keys[] = { kAXTrustedCheckOptionPrompt };
    const void *vals[] = { kCFBooleanTrue };
    CFDictionaryRef opts = CFDictionaryCreate(NULL, keys, vals, 1, &kCFCopyStringDictionaryKeyCallBacks,
                                              &kCFTypeDictionaryValueCallBacks);
    bool ok = AXIsProcessTrustedWithOptions(opts);
    CFRelease(opts);
    return ok ? 0 : 2;
  }
  if (strcmp(argv[1], "-k") == 0) {
    const void *keys[] = { kTISPropertyInputSourceCategory, kTISPropertyInputSourceIsSelectCapable };
    const void *vals[] = { kTISCategoryKeyboardInputSource, kCFBooleanTrue };
    CFDictionaryRef filter = CFDictionaryCreate(NULL, keys, vals, 2, &kCFTypeDictionaryKeyCallBacks,
                                                &kCFTypeDictionaryValueCallBacks);
    CFArrayRef sources = TISCreateInputSourceList(filter, false);
    CFRelease(filter);
    TISInputSourceRef current = TISCopyCurrentKeyboardInputSource();
    CFIndex n = sources ? CFArrayGetCount(sources) : 0, at = -1;
    CFStringRef cur_id = current ? TISGetInputSourceProperty(current, kTISPropertyInputSourceID) : NULL;
    for (CFIndex i = 0; i < n && cur_id; i++) {
      TISInputSourceRef s = (TISInputSourceRef)CFArrayGetValueAtIndex(sources, i);
      if (CFEqual(TISGetInputSourceProperty(s, kTISPropertyInputSourceID), cur_id)) at = i;
    }
    if (n > 1) TISSelectInputSource((TISInputSourceRef)CFArrayGetValueAtIndex(sources, (at + 1) % n));
    if (current) CFRelease(current);
    if (sources) CFRelease(sources);
    return 0;
  }
  if (strcmp(argv[1], "-d") == 0) {
    // The active display is the one whose menu bar is "live" (SkyLight's
    // notion, which SketchyBar's `display=active` also follows).
    typedef CFStringRef (*active_fn)(int);
    typedef int (*cid_fn)(void);
    void *sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY);
    active_fn active = sky ? (active_fn)dlsym(sky, "SLSCopyActiveMenuBarDisplayIdentifier") : NULL;
    cid_fn cid = sky ? (cid_fn)dlsym(sky, "SLSMainConnectionID") : NULL;
    CFStringRef active_uuid = (active && cid) ? active(cid()) : NULL;
    CGDirectDisplayID ids[16];
    uint32_t count = 0;
    CGGetActiveDisplayList(16, ids, &count);
    for (uint32_t i = 0; i < count; i++) {
      bool is_active = count == 1;
      CFUUIDRef uuid = CGDisplayCreateUUIDFromDisplayID(ids[i]);
      if (uuid && active_uuid) {
        CFStringRef str = CFUUIDCreateString(NULL, uuid);
        is_active = CFStringCompare(str, active_uuid, kCFCompareCaseInsensitive) == kCFCompareEqualTo;
        CFRelease(str);
      }
      if (uuid) CFRelease(uuid);
      printf("%u\t%d\t%d\t%.0f\n", ids[i], CGDisplayIsBuiltin(ids[i]) ? 1 : 0, is_active ? 1 : 0,
             CGDisplayBounds(ids[i]).size.width);
    }
    if (active_uuid) CFRelease(active_uuid);
    return 0;
  }
  if (!AXIsProcessTrusted()) {
    fprintf(stderr, "sbmenus: Accessibility permission missing\n");
    return 2;
  }
  if (strcmp(argv[1], "-l") == 0) front_menus(-1);
  else if (strcmp(argv[1], "-s") == 0 && argc >= 3) front_menus(atol(argv[2]));
  else if (strcmp(argv[1], "-t") == 0) each_icon(print_icon, NULL);
  else if (strcmp(argv[1], "-x") == 0 && argc >= 3) {
    struct match m = { (pid_t)atoi(argv[2]), NULL };
    each_icon(press_match, &m);
  } else if (strcmp(argv[1], "-i") == 0 && argc >= 3) {
    struct match m = { 0, argv[2] };
    each_icon(press_match, &m);
  } else return 1;
  return 0;
}
