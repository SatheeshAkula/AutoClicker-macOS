#!/usr/bin/env python3
"""
auto_click_native.py
Zero-dependency, fully portable Python implementation of the AutoClicker utility.
Uses macOS CoreGraphics and Carbon via ctypes.
Requires NO virtualenv, NO pip install, NO pyautogui, and NO pynput!
Compatible with Python 3 on macOS.
"""

import time
import sys
import ctypes
import ctypes.util
import threading
import signal

# ----------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------
INITIAL_DELAY = 3.0
STEP_DELAY = 2.5

# macOS Virtual Keycodes (from Carbon HIToolbox/Events.h)
kVK_DownArrow = 0x7D  # 125
kVK_ANSI_D    = 0x02  # 2
kVK_Escape    = 0x35  # 53

# Load macOS CoreGraphics framework
cg_path = ctypes.util.find_library("CoreGraphics") or "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
cg = ctypes.cdll.LoadLibrary(cg_path)

# Load ApplicationServices for AXIsProcessTrusted
as_path = ctypes.util.find_library("ApplicationServices") or "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
app_services = ctypes.cdll.LoadLibrary(as_path)

# CoreGraphics Types & Signatures
class CGPoint(ctypes.Structure):
    _fields_ = [("x", ctypes.c_double), ("y", ctypes.c_double)]

cg.CGEventCreateKeyboardEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint16, ctypes.c_bool]
cg.CGEventCreateKeyboardEvent.restype = ctypes.c_void_p

cg.CGEventCreateMouseEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint32, CGPoint, ctypes.c_uint32]
cg.CGEventCreateMouseEvent.restype = ctypes.c_void_p

cg.CGEventCreate.argtypes = [ctypes.c_void_p]
cg.CGEventCreate.restype = ctypes.c_void_p

cg.CGEventGetLocation.argtypes = [ctypes.c_void_p]
cg.CGEventGetLocation.restype = CGPoint

cg.CGEventPost.argtypes = [ctypes.c_uint32, ctypes.c_void_p]
cg.CGEventPost.restype = None

# CFRelease
cf_path = ctypes.util.find_library("CoreFoundation") or "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
cf = ctypes.cdll.LoadLibrary(cf_path)
cf.CFRelease.argtypes = [ctypes.c_void_p]
cf.CFRelease.restype = None

# Event tap constants
kCGHIDEventTap = 0
kCGSessionEventTap = 1
kCGHeadInsertEventTap = 0
kCGEventTapOptionListenOnly = 1
kCGEventKeyDown = 10
kCGKeyboardEventKeycode = 9
kCGEventLeftMouseDown = 1
kCGEventLeftMouseUp = 2
kCGMouseButtonLeft = 0

cg.CGEventGetIntegerValueField.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
cg.CGEventGetIntegerValueField.restype = ctypes.c_int64

app_services.AXIsProcessTrusted.restype = ctypes.c_bool

# Global stop flag
stop_program = False


def interruptible_sleep(seconds):
    """Sleeps in 20ms slices so Esc or Ctrl+C terminates immediately."""
    end_time = time.time() + seconds
    while not stop_program and time.time() < end_time:
        time.sleep(0.02)


def press_key(keycode):
    """Simulates a key press and release using CoreGraphics."""
    down = cg.CGEventCreateKeyboardEvent(None, keycode, True)
    up = cg.CGEventCreateKeyboardEvent(None, keycode, False)
    if down and up:
        cg.CGEventPost(kCGHIDEventTap, down)
        time.sleep(0.015)
        cg.CGEventPost(kCGHIDEventTap, up)
    if down:
        cf.CFRelease(down)
    if up:
        cf.CFRelease(up)


def click_mouse():
    """Simulates a left click at the current mouse cursor location."""
    cur = cg.CGEventCreate(None)
    if not cur:
        return
    loc = cg.CGEventGetLocation(cur)
    cf.CFRelease(cur)

    down = cg.CGEventCreateMouseEvent(None, kCGEventLeftMouseDown, loc, kCGMouseButtonLeft)
    up = cg.CGEventCreateMouseEvent(None, kCGEventLeftMouseUp, loc, kCGMouseButtonLeft)
    if down and up:
        cg.CGEventPost(kCGHIDEventTap, down)
        time.sleep(0.015)
        cg.CGEventPost(kCGHIDEventTap, up)
    if down:
        cf.CFRelease(down)
    if up:
        cf.CFRelease(up)


def start_esc_listener():
    """Runs a background thread with an event tap listening for ESC."""
    CALLBACK = ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_void_p)

    def event_callback(proxy, event_type, event, refcon):
        global stop_program
        if event_type == kCGEventKeyDown:
            keycode = cg.CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode)
            if keycode == kVK_Escape:
                print("\n[Esc pressed] Stopping...")
                stop_program = True
        return event

    # Keep a reference to prevent garbage collection
    event_callback._c_func = CALLBACK(event_callback)

    def run_tap():
        mask = (1 << kCGEventKeyDown)
        tap = cg.CGEventTapCreate(
            kCGSessionEventTap,
            kCGHeadInsertEventTap,
            kCGEventTapOptionListenOnly,
            mask,
            event_callback._c_func,
            None
        )
        if not tap:
            return

        source = cf.CFMachPortCreateRunLoopSource(None, tap, 0)
        loop = cf.CFRunLoopGetCurrent()
        cf.CFRunLoopAddSource(loop, source, cf.kCFRunLoopCommonModes)
        cg.CGEventTapEnable(tap, True)

        while not stop_program:
            cf.CFRunLoopRunInMode(cf.kCFRunLoopDefaultMode, ctypes.c_double(0.1), False)

        cf.CFRelease(source)
        cf.CFRelease(tap)

    thread = threading.Thread(target=run_tap, daemon=True)
    thread.start()
    return thread


def handle_sigint(sig, frame):
    global stop_program
    print("\nInterrupt signal received. Stopping...")
    stop_program = True


def main():
    global stop_program

    signal.signal(signal.SIGINT, handle_sigint)
    signal.signal(signal.SIGTERM, handle_sigint)

    trusted = app_services.AXIsProcessTrusted()
    if not trusted:
        print("Notice: macOS Accessibility permission may be required.")
        print("Go to: System Settings > Privacy & Security > Accessibility\n")

    print("=====================================================")
    print("  AutoClicker (Zero-Dependency Native Python)        ")
    print("=====================================================")
    print("Sequence:  Down Arrow -> 'd' -> Left Click")
    print(f"Delays:    Initial: {INITIAL_DELAY}s | Step: {STEP_DELAY}s")
    print("Stop:      Press ESC anywhere at any time to STOP")
    print("=====================================================\n")

    print(f"Program will start in {INITIAL_DELAY:.1f} seconds...")
    print("Press ESC at any time to stop.")

    start_esc_listener()

    # Countdown
    for sec in range(int(INITIAL_DELAY), 0, -1):
        if stop_program:
            break
        print(f"Starting in {sec}...")
        interruptible_sleep(1.0)

    if stop_program:
        print("Cancelled before start.")
        return

    print("\n>>> Started! Running automation loop... <<<")

    cycle = 0
    try:
        while not stop_program:
            cycle += 1

            # 1. Press Down Arrow
            sys.stdout.write(f"\r[Cycle {cycle:4d}] ⬇️  Down Arrow")
            sys.stdout.flush()
            press_key(kVK_DownArrow)
            interruptible_sleep(STEP_DELAY)
            if stop_program:
                break

            # 2. Press D
            sys.stdout.write(f"\r[Cycle {cycle:4d}] ⌨️  Press 'd'  ")
            sys.stdout.flush()
            press_key(kVK_ANSI_D)
            interruptible_sleep(STEP_DELAY)
            if stop_program:
                break

            # 3. Left click
            sys.stdout.write(f"\r[Cycle {cycle:4d}] 🖱️  Left Click ")
            sys.stdout.flush()
            click_mouse()
            interruptible_sleep(STEP_DELAY)

    finally:
        stop_program = True
        print(f"\nProgram stopped. Total completed cycles: {cycle}")


if __name__ == "__main__":
    main()
