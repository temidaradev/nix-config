// Long-running event providers for SketchyBar, so the bar doesn't poll:
//
//   sbwatch net            trigger `network_change` whenever the primary
//                          network service, an interface address or Wi-Fi
//                          state changes (SCDynamicStore notifications)
//   sbwatch stats SECONDS  every SECONDS, one `stats_update` event carrying
//                          CPU      load % over the interval (processor tick deltas)
//                          RX TX    bytes/s on the physical en* interfaces
//                          WATTS    whole-system power draw (battery telemetry)
//                          BATT     charge %, CHARGING / AC 0|1,
//                          MINUTES  time to empty (or to full while charging), -1 unknown
//                          all read natively: no ps/pmset/ioreg processes.
//
// Both exit on their own once SketchyBar is gone.
#include <IOKit/IOKitLib.h>
#include <SystemConfiguration/SystemConfiguration.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <libproc.h>
#include <mach/mach.h>
#include <spawn.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
#include <time.h>

extern char **environ;

static void trigger_args(char **args) {
  pid_t pid;
  if (posix_spawnp(&pid, "sketchybar", NULL, NULL, args, environ) == 0) waitpid(pid, NULL, 0);
}

static void trigger(const char *event, const char *arg) {
  char *argv[] = { "sketchybar", "--trigger", (char *)event, (char *)arg, NULL };
  if (!arg) argv[3] = NULL;
  pid_t pid;
  if (posix_spawnp(&pid, "sketchybar", NULL, NULL, argv, environ) == 0) waitpid(pid, NULL, 0);
}

static bool sketchybar_running(void) {
  int n = proc_listallpids(NULL, 0);
  if (n <= 0) return true;  // can't tell; keep going
  pid_t *pids = calloc(n * 2, sizeof(pid_t));
  n = proc_listallpids(pids, n * 2 * sizeof(pid_t));
  bool found = false;
  for (int i = 0; i < n && !found; i++) {
    char name[64];
    if (pids[i] > 0 && proc_name(pids[i], name, sizeof name) > 0 && strcmp(name, "sketchybar") == 0) found = true;
  }
  free(pids);
  return found;
}

// ---- network ----

static void net_changed(SCDynamicStoreRef store, CFArrayRef keys, void *info) {
  (void)store; (void)keys; (void)info;
  trigger("network_change", NULL);
}

static void net_alive(CFRunLoopTimerRef timer, void *info) {
  (void)timer; (void)info;
  if (!sketchybar_running()) exit(0);
}

static int watch_net(void) {
  SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("sbwatch"), net_changed, NULL);
  if (!store) return 1;
  CFStringRef keys[] = { CFSTR("State:/Network/Global/IPv4") };
  CFStringRef patterns[] = {
    CFSTR("State:/Network/Interface/.*/IPv4"),
    CFSTR("State:/Network/Interface/.*/Link"),
    CFSTR("State:/Network/Interface/.*/AirPort"),
  };
  CFArrayRef key_list = CFArrayCreate(NULL, (const void **)keys, 1, &kCFTypeArrayCallBacks);
  CFArrayRef pattern_list = CFArrayCreate(NULL, (const void **)patterns, 3, &kCFTypeArrayCallBacks);
  SCDynamicStoreSetNotificationKeys(store, key_list, pattern_list);
  CFRunLoopSourceRef source = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
  CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
  CFRunLoopTimerRef alive = CFRunLoopTimerCreate(NULL, CFAbsoluteTimeGetCurrent() + 30, 30, 0, 0, net_alive, NULL);
  CFRunLoopAddTimer(CFRunLoopGetCurrent(), alive, kCFRunLoopDefaultMode);
  CFRunLoopRun();
  return 0;
}

// ---- stats ----

static bool cpu_ticks(uint64_t *busy, uint64_t *total) {
  natural_t count;
  processor_info_array_t info;
  mach_msg_type_number_t info_count;
  if (host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &info_count) != KERN_SUCCESS)
    return false;
  *busy = *total = 0;
  for (natural_t i = 0; i < count; i++) {
    unsigned int *t = (unsigned int *)&info[i * CPU_STATE_MAX];
    uint64_t used = (uint64_t)t[CPU_STATE_USER] + t[CPU_STATE_SYSTEM] + t[CPU_STATE_NICE];
    *busy += used;
    *total += used + t[CPU_STATE_IDLE];
  }
  vm_deallocate(mach_task_self(), (vm_address_t)info, info_count * sizeof(integer_t));
  return true;
}

// Bytes in/out over the physical interfaces (en*): VPN tunnels carry the same
// traffic again, so they're left out. 32-bit counters; deltas wrap correctly.
static void net_bytes(uint32_t *rx, uint32_t *tx) {
  struct ifaddrs *list = NULL, *i;
  *rx = *tx = 0;
  if (getifaddrs(&list) != 0) return;
  for (i = list; i; i = i->ifa_next) {
    if (!i->ifa_addr || i->ifa_addr->sa_family != AF_LINK || !i->ifa_data) continue;
    if (strncmp(i->ifa_name, "en", 2) != 0) continue;
    struct if_data *d = (struct if_data *)i->ifa_data;
    *rx += d->ifi_ibytes;
    *tx += d->ifi_obytes;
  }
  freeifaddrs(list);
}

static long dict_long(CFDictionaryRef d, const char *key, long fallback) {
  if (!d) return fallback;
  CFStringRef k = CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
  CFTypeRef v = CFDictionaryGetValue(d, k);
  CFRelease(k);
  long out = fallback;
  if (v && CFGetTypeID(v) == CFNumberGetTypeID()) CFNumberGetValue(v, kCFNumberLongType, &out);
  else if (v && CFGetTypeID(v) == CFBooleanGetTypeID()) out = CFBooleanGetValue(v);
  return out;
}

struct battery { long pct, charging, ac, minutes, milliwatts; bool present; };

static struct battery read_battery(void) {
  struct battery b = { -1, 0, 0, -1, -1, false };
  io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"));
  if (!svc) return b;
  CFMutableDictionaryRef props = NULL;
  if (IORegistryEntryCreateCFProperties(svc, &props, NULL, 0) == KERN_SUCCESS && props) {
    b.present = true;
    long cur = dict_long(props, "CurrentCapacity", -1), max = dict_long(props, "MaxCapacity", 100);
    b.pct = (cur >= 0 && max > 0) ? (cur * 100 + max / 2) / max : -1;
    b.charging = dict_long(props, "IsCharging", 0);
    b.ac = dict_long(props, "ExternalConnected", 0);
    long t = b.charging ? dict_long(props, "AvgTimeToFull", 65535) : dict_long(props, "AvgTimeToEmpty", 65535);
    b.minutes = (t > 0 && t < 65535) ? t : -1;
    CFTypeRef tele = CFDictionaryGetValue(props, CFSTR("PowerTelemetryData"));
    if (tele && CFGetTypeID(tele) == CFDictionaryGetTypeID()) b.milliwatts = dict_long(tele, "SystemLoad", -1);
    CFRelease(props);
  }
  IOObjectRelease(svc);
  return b;
}

// Monotonic elapsed time includes scheduling/IPC overhead, not just the sleep.
static double monotonic_seconds(void) {
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec + t.tv_nsec / 1e9;
}
static int watch_stats(double seconds) {
  if (seconds < 1) seconds = 1;
  uint64_t busy0 = 0, total0 = 0;
  uint32_t rx0 = 0, tx0 = 0;
  cpu_ticks(&busy0, &total0);
  net_bytes(&rx0, &tx0);
  double previous = monotonic_seconds(), checked = previous;
  for (;;) {
    struct timespec delay = { (time_t)seconds, (long)((seconds - (time_t)seconds) * 1e9) };
    nanosleep(&delay, NULL);
    double now = monotonic_seconds(), elapsed = now - previous;
    if (now - checked >= 60) {
      if (!sketchybar_running()) return 0;
      checked = now;
    }
    uint64_t busy, total;
    uint32_t rx, tx;
    if (!cpu_ticks(&busy, &total)) continue;
    net_bytes(&rx, &tx);
    uint64_t db = busy - busy0, dt = total - total0;
    // Reset rather than interpreting a removed interface as counter wrap.
    double rx_rate = rx >= rx0 && elapsed > 0 ? (rx - rx0) / elapsed : 0;
    double tx_rate = tx >= tx0 && elapsed > 0 ? (tx - tx0) / elapsed : 0;
    previous = now;
    busy0 = busy; total0 = total; rx0 = rx; tx0 = tx;
    struct battery b = read_battery();

    char cpu[32], rxs[32], txs[32], watts[32], batt[32], chg[16], ac[16], mins[32];
    snprintf(cpu, sizeof cpu, "CPU=%d", dt ? (int)(100.0 * db / dt + 0.5) : 0);
    snprintf(rxs, sizeof rxs, "RX=%.0f", rx_rate);
    snprintf(txs, sizeof txs, "TX=%.0f", tx_rate);
    snprintf(watts, sizeof watts, "WATTS=%.1f", b.milliwatts >= 0 ? b.milliwatts / 1000.0 : -1.0);
    snprintf(batt, sizeof batt, "BATT=%ld", b.present ? b.pct : -1);
    snprintf(chg, sizeof chg, "CHARGING=%ld", b.charging);
    snprintf(ac, sizeof ac, "AC=%ld", b.ac);
    snprintf(mins, sizeof mins, "MINUTES=%ld", b.minutes);
    char *args[] = { "sketchybar", "--trigger", "stats_update", cpu, rxs, txs, watts, batt, chg, ac, mins, NULL };
    trigger_args(args);
  }
}

int main(int argc, char **argv) {
  if (argc >= 2 && strcmp(argv[1], "net") == 0) return watch_net();
  if (argc >= 3 && strcmp(argv[1], "stats") == 0) return watch_stats(atof(argv[2]));
  fprintf(stderr, "usage: %s net | stats SECONDS\n", argv[0]);
  return 1;
}
