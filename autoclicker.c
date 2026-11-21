#include <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>
#include <getopt.h>

#define DEFAULT_INITIAL_DELAY 3.0
#define DEFAULT_STEP_DELAY    0.5

// Global state
static volatile bool g_running = true;
static CFRunLoopRef g_runLoop = NULL;

// Sleep in short 20ms chunks so ESC or Ctrl+C breaks immediately
static void interruptible_sleep(double seconds) {
    long total_us = (long)(seconds * 1000000.0);
    const long chunk_us = 20000; // 20ms
    while (g_running && total_us > 0) {
        long slice = (total_us > chunk_us) ? chunk_us : total_us;
        usleep((useconds_t)slice);
        total_us -= slice;
    }
}

// Signal handler for Ctrl+C / SIGTERM
static void signal_handler(int sig) {
    (void)sig;
    g_running = false;
    if (g_runLoop) {
        CFRunLoopStop(g_runLoop);
    }
}

// Global keyboard event tap callback
static CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    (void)proxy;
    (void)refcon;

    // If macOS disabled the event tap due to timeout, re-enable it
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        CGEventTapEnable((CFMachPortRef)refcon, true);
        return event;
    }

    if (type == kCGEventKeyDown) {
        CGKeyCode keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        if (keycode == kVK_Escape) {
            printf("\n[Esc pressed] Stopping...\n");
            g_running = false;
            if (g_runLoop) {
                CFRunLoopStop(g_runLoop);
            }
        }
    }
    return event;
}

// Background thread listening for global ESC key
static void* keyboardListenerThread(void *arg) {
    (void)arg;
    CGEventMask mask = (1 << kCGEventKeyDown);
    CFMachPortRef eventTap = CGEventTapCreate(
        kCGSessionEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionListenOnly,
        mask,
        eventTapCallback,
        NULL
    );

    if (!eventTap) {
        fprintf(stderr, "\nNotice: Global Esc key listener could not be registered.\n"
                        "Keystroke simulation may still work, and you can stop with Ctrl+C in Terminal.\n"
                        "To enable global Esc detection, ensure Accessibility permission is enabled.\n\n");
        return NULL;
    }

    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    g_runLoop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(g_runLoop, runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(eventTap, true);

    CFRunLoopRun();

    CFRelease(runLoopSource);
    CFRelease(eventTap);
    return NULL;
}

// Key simulation
static void send_key(CGKeyCode key_code) {
    CGEventRef down = CGEventCreateKeyboardEvent(NULL, key_code, true);
    CGEventRef up   = CGEventCreateKeyboardEvent(NULL, key_code, false);

    if (down && up) {
        CGEventPost(kCGHIDEventTap, down);
        usleep(15000); // 15ms key hold
        CGEventPost(kCGHIDEventTap, up);
    }

    if (down) CFRelease(down);
    if (up)   CFRelease(up);
}

// Mouse left click simulation at current cursor position
static void send_click(void) {
    CGEventRef cur = CGEventCreate(NULL);
    if (!cur) return;

    CGPoint loc = CGEventGetLocation(cur);
    CFRelease(cur);

    CGEventRef down = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, loc, kCGMouseButtonLeft);
    CGEventRef up   = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, loc, kCGMouseButtonLeft);

    if (down && up) {
        CGEventPost(kCGHIDEventTap, down);
        usleep(15000); // 15ms click hold
        CGEventPost(kCGHIDEventTap, up);
    }

    if (down) CFRelease(down);
    if (up)   CFRelease(up);
}

// Check and prompt for macOS Accessibility permissions
static bool check_accessibility(bool prompt_user) {
    if (AXIsProcessTrusted()) {
        return true;
    }
    if (prompt_user) {
        const void *keys[] = { kAXTrustedCheckOptionPrompt };
        const void *values[] = { kCFBooleanTrue };
        CFDictionaryRef options = CFDictionaryCreate(
            kCFAllocatorDefault,
            keys,
            values,
            1,
            &kCFTypeDictionaryKeyCallBacks,
            &kCFTypeDictionaryValueCallBacks
        );
        AXIsProcessTrustedWithOptions(options);
        CFRelease(options);
    }
    return false;
}

static void print_usage(const char *prog_name) {
    printf("AutoClicker - Lightweight, portable macOS automation utility\n");
    printf("Replicates: Down Arrow -> 'd' -> Left Click loop with global ESC stop.\n\n");
    printf("Usage:\n");
    printf("  %s [options]\n\n", prog_name);
    printf("Options:\n");
    printf("  -i, --initial <sec>   Initial delay before starting (default: %.1f s)\n", DEFAULT_INITIAL_DELAY);
    printf("  -s, --step <sec>      Delay after each step (default: %.1f s)\n", DEFAULT_STEP_DELAY);
    printf("  -n, --count <num>     Number of cycles to run (default: infinite)\n");
    printf("      --down-delay <s>  Specific delay after Down Arrow (overrides --step)\n");
    printf("      --d-delay <s>     Specific delay after 'd' (overrides --step)\n");
    printf("      --click-delay <s> Specific delay after click (overrides --step)\n");
    printf("      --dry-run         Print actions without sending actual input events\n");
    printf("  -h, --help            Show this help message\n\n");
    printf("Controls:\n");
    printf("  ESC     Press ESC at any time to immediately stop the program\n");
    printf("  Ctrl+C  Stop the program from terminal\n");
}

int main(int argc, char *argv[]) {
    double initial_delay = DEFAULT_INITIAL_DELAY;
    double step_delay = DEFAULT_STEP_DELAY;
    double delay_down = -1.0;
    double delay_d = -1.0;
    double delay_click = -1.0;
    int max_cycles = 0;
    bool dry_run = false;

    enum {
        OPT_DOWN_DELAY = 1000,
        OPT_D_DELAY,
        OPT_CLICK_DELAY,
        OPT_DRY_RUN
    };

    static struct option long_options[] = {
        {"initial",     required_argument, 0, 'i'},
        {"step",        required_argument, 0, 's'},
        {"count",       required_argument, 0, 'n'},
        {"down-delay",  required_argument, 0, OPT_DOWN_DELAY},
        {"d-delay",     required_argument, 0, OPT_D_DELAY},
        {"click-delay", required_argument, 0, OPT_CLICK_DELAY},
        {"dry-run",     no_argument,       0, OPT_DRY_RUN},
        {"help",        no_argument,       0, 'h'},
        {0, 0, 0, 0}
    };

    int opt;
    while ((opt = getopt_long(argc, argv, "i:s:n:h", long_options, NULL)) != -1) {
        switch (opt) {
            case 'i':
                initial_delay = atof(optarg);
                if (initial_delay < 0) initial_delay = 0;
                break;
            case 's':
                step_delay = atof(optarg);
                if (step_delay < 0) step_delay = 0;
                break;
            case 'n':
                max_cycles = atoi(optarg);
                if (max_cycles < 0) max_cycles = 0;
                break;
            case OPT_DOWN_DELAY:
                delay_down = atof(optarg);
                break;
            case OPT_D_DELAY:
                delay_d = atof(optarg);
                break;
            case OPT_CLICK_DELAY:
                delay_click = atof(optarg);
                break;
            case OPT_DRY_RUN:
                dry_run = true;
                break;
            case 'h':
                print_usage(argv[0]);
                return 0;
            default:
                print_usage(argv[0]);
                return 1;
        }
    }

    if (delay_down < 0)  delay_down = step_delay;
    if (delay_d < 0)     delay_d = step_delay;
    if (delay_click < 0) delay_click = step_delay;

    // Check accessibility permissions
    if (!dry_run && !check_accessibility(false)) {
        printf("====================================================================\n");
        printf("⚠️  macOS Accessibility Permission Required\n");
        printf("====================================================================\n");
        printf("This tool simulates keystrokes/clicks and listens for the ESC key.\n");
        printf("macOS requires Accessibility permissions for this.\n\n");
        printf("Requesting system permission dialog now...\n");
        check_accessibility(true);
        printf("Please ensure Terminal (or this app) is checked in:\n");
        printf("  System Settings > Privacy & Security > Accessibility\n");
        printf("Then re-run this tool.\n");
        printf("====================================================================\n\n");
    }

    // Set up signal handlers for graceful exit
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    // Start background thread for global ESC key detection
    pthread_t listener_tid;
    pthread_create(&listener_tid, NULL, keyboardListenerThread, NULL);

    printf("=====================================================\n");
    printf("  AutoClicker Utility (Portable macOS Native)        \n");
    printf("=====================================================\n");
    printf("Sequence:    Down Arrow -> 'd' -> Left Click\n");
    printf("Delays:      Step: %.2fs (Down: %.2fs, 'd': %.2fs, Click: %.2fs)\n",
           step_delay, delay_down, delay_d, delay_click);
    if (max_cycles > 0) {
        printf("Limit:       %d cycles\n", max_cycles);
    } else {
        printf("Limit:       Infinite (until ESC or Ctrl+C)\n");
    }
    if (dry_run) {
        printf("Mode:        DRY RUN (no inputs will be sent)\n");
    }
    printf("Emergency:   Press ESC anywhere at any time to STOP\n");
    printf("=====================================================\n\n");

    int cycle = 0;

    // Initial countdown
    printf("Program will start in %.1f seconds...\n", initial_delay);
    printf("Press ESC at any time to stop.\n");

    int countdown_secs = (int)initial_delay;
    double frac = initial_delay - countdown_secs;
    if (frac > 0) {
        interruptible_sleep(frac);
    }

    for (int sec = countdown_secs; sec > 0 && g_running; sec--) {
        printf("Starting in %d...\n", sec);
        fflush(stdout);
        interruptible_sleep(1.0);
    }

    if (!g_running) {
        printf("Cancelled before start.\n");
        goto cleanup;
    }

    printf("\n>>> Started! Running automation loop... <<<\n");
    fflush(stdout);
    while (g_running) {
        if (max_cycles > 0 && cycle >= max_cycles) {
            printf("\nReached target cycle count (%d).\n", max_cycles);
            break;
        }

        cycle++;

        // 1. Press Down Arrow
        printf("\r\033[K[Cycle %4d] ⬇️  Down Arrow", cycle);
        fflush(stdout);
        if (!dry_run) send_key(kVK_DownArrow);
        interruptible_sleep(delay_down);
        if (!g_running) break;

        // 2. Press D
        printf("\r\033[K[Cycle %4d] ⌨️  Press 'd'  ", cycle);
        fflush(stdout);
        if (!dry_run) send_key(kVK_ANSI_D);
        interruptible_sleep(delay_d);
        if (!g_running) break;

        // 3. Left Click at current position
        printf("\r\033[K[Cycle %4d] 🖱️  Left Click ", cycle);
        fflush(stdout);
        if (!dry_run) send_click();
        interruptible_sleep(delay_click);
    }

cleanup:
    g_running = false;
    if (g_runLoop) {
        CFRunLoopStop(g_runLoop);
    }
    pthread_join(listener_tid, NULL);

    printf("\nProgram stopped. Total completed cycles: %d\n", cycle);
    return 0;
}
