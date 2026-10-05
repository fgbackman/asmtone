// main.s — asmtone: send text as sound. A Cocoa window, a menu-bar item and a Dock icon,
// written in ARM64 assembly against the Objective-C runtime.
//
//   asmtone              the app
//   asmtone --selftest   the modem's self-tests (exit code = failures)

.include "macros.inc"

// NSAutoresizingMask
.set AR_MINX,  1
.set AR_W,     2
.set AR_MINY,  8
.set AR_H,     16
.set AR_MAXY,  32

.set K_SENT,   0
.set K_HEARD,  1
.set K_BAD,    2

// load frame #n of Lframes into d0-d3
.macro FRAME n
    ADRL x9, Lframes
    add  x9, x9, #(\n * 32)
    ldp  d0, d1, [x9]
    ldp  d2, d3, [x9, #16]
.endm

// a global object pointer
.macro GET reg, sym
    ADRL \reg, \sym
    ldr  \reg, [\reg]
.endm
.macro PUT reg, sym
    ADRL x17, \sym
    str  \reg, [x17]
.endm

.section __TEXT,__const
.p2align 3
Lframes:                                  // x, y, w, h in a 560 x 600 window
    .double 20, 556, 300, 24              // 0  mode
    .double 334, 559, 210, 17             // 1  speed
    .double 20, 470, 520, 74              // 2  message
    .double 14, 426, 110, 32              // 3  Play
    .double 132, 433, 408, 17             // 4  estimate
    .double 20, 388, 76, 18               // 5  Listen
    .double 100, 389, 150, 14             // 6  level
    .double 262, 388, 278, 17             // 7  status
    .double 20, 56, 520, 316              // 8  heard
    .double 14, 12, 132, 32               // 9  Copy Last
    .double 144, 12, 90, 32               // 10 Clear
    .double 244, 20, 296, 17              // 11 counts
Lc_win:     .double 0, 0, 560, 600
Lc_minsz:   .double 480, 470
Lc_varlen:  .double -1.0
Lc_tick:    .double 0.1
Lc_unmute:  .double 0.4
Lc_one:     .double 1.0
Lc_dim:     .double 0.45
Lc_zero:    .double 0.0
Lc_f12:     .double 12.0
Lc_f13:     .double 13.0
Lc_f15:     .double 15.0
Lc_sr:      .double 48000.0
.p2align 2
Lk_db:      .float 20.0
Lk_db60:    .float 60.0
Lk_inv60:   .float 0.016666666666666666
Lk_fall:    .float 0.06
Lk_tiny:    .float 1.0e-6
Lk_clip:    .float 0.98

.section __TEXT,__cstring
Ls_selftest_flag: .asciz "--selftest"
Ls_title:       .asciz "asmtone"
Ls_ctl_name:    .asciz "ATController"
Ls_piano:       .asciz "Piano"
Ls_chirp:       .asciz "Chirp"
Ls_fast:        .asciz "Fast"
Ls_silent:      .asciz "Silent"
Ls_duet:        .asciz "Duet"
Ls_sp_piano:    .asciz "up to 6 characters a second"
Ls_sp_chirp:    .asciz "up to 25 characters a second"
Ls_sp_fast:     .asciz "up to 90 a second, up close"
Ls_sp_silent:   .asciz "up to 22 a second, near-silent"
Ls_sp_duet:     .asciz "two hands, up to 9 a second, up close"
Ls_placeholder: .asciz "Type a message, then press Return to play it"
Ls_est_empty:   .asciz "Other Macs running asmtone will write it down."
Ls_est_fmt:     .asciz "%ld characters \302\267 %.1f seconds of sound"
Ls_est_long:    .asciz "%ld characters \342\200\224 too long for one %s message"
Ls_play:        .asciz "Play"
Ls_stop:        .asciz "Stop"
Ls_listen:      .asciz "Listen"
Ls_copylast:    .asciz "Copy Last"
Ls_clear:       .asciz "Clear"
Ls_st_play:     .asciz "Playing\342\200\246"
Ls_st_listen:   .asciz "Listening for every mode"
Ls_st_off:      .asciz "Not listening"
Ls_st_hear:     .asciz "Hearing %s\342\200\246 %ld%%"
Ls_st_mic:      .asciz "Microphone access is off (System Settings \342\200\272 Privacy & Security \342\200\272 Microphone)"
Ls_st_err:      .asciz "Couldn't open the microphone (%ld) \342\200\224 try Listen again"
Ls_st_long:     .asciz "Too long for one %s message \342\200\224 shorten it or send it in parts"
Ls_st_busy:     .asciz "Still playing \342\200\224 press Stop first"
Ls_st_noclip:   .asciz "The clipboard has no text"
Ls_counts:      .asciz "%ld heard \302\267 %ld repaired \302\267 %ld lost"
Ls_time:        .asciz "%H:%M:%S"
Ls_pre_sent:    .asciz "%s  %-5s \342\226\270  "
Ls_pre_heard:   .asciz "%s  %-5s \342\227\202  "
Ls_bad_text:    .asciz "a message arrived too damaged to read"
Ls_nohdr_text:  .asciz "heard the start of a message but couldn't read its length"
Ls_mi_rec:      .asciz "Save Last Minute of Sound"
Ls_mi_failed:   .asciz "Show Last Failed Message"
Ls_a_failed:    .asciz "showFailed:"
Ls_fail_dir:    .asciz "%s/Library/Application Support/asmtone"
Ls_fail_path:   .asciz "%s/last-failed-message.wav"
Ls_fail_none:   .asciz "No failed message yet"
Ls_fast_far:    .asciz "Fast and Duet need the Macs close together \342\200\224 from further away use Chirp, Silent or Piano"
Ls_st_clip:     .asciz "Too loud: the microphone is overloading \342\200\224 turn the other Mac down or move apart"
Ls_NSWorkspace: .asciz "NSWorkspace"
Ls_NSURL:       .asciz "NSURL"
Ls_sharedWS:    .asciz "sharedWorkspace"
Ls_fileURL:     .asciz "fileURLWithPath:"
Ls_activateFV:  .asciz "activateFileViewerSelectingURLs:"
Ls_a_rec:       .asciz "saveRecording:"
Ls_key_s:       .asciz "s"
Ls_rec_dir1:    .asciz "%s/Developer/asmtone/recordings"
Ls_rec_dir2:    .asciz "%s/Desktop"
Ls_rec_time:    .asciz "%Y%m%d-%H%M%S"
Ls_rec_path:    .asciz "%s/heard-%s.wav"
Ls_rec_ok:      .asciz "Saved the last minute: %s"
Ls_rec_fail:    .asciz "Couldn't save the recording (is Listen on?)"
Ls_fixed_fmt:   .asciz "   (%ld bytes repaired)"
Ls_nl:          .asciz "\n"
Ls_badge:       .asciz "%ld"
Ls_k_mode:      .asciz "mode"
Ls_k_listenoff: .asciz "listenOff"
Ls_k_frame:     .asciz "asmtone main window"
Ls_sym_main:    .asciz "pianokeys"
Ls_sym_alt:     .asciz "music.note"
Ls_mi_piano:    .asciz "Send Clipboard as Piano"
Ls_mi_chirp:    .asciz "Send Clipboard as Chirp"
Ls_mi_fast:     .asciz "Send Clipboard as Fast"
Ls_mi_silent:   .asciz "Send Clipboard as Silent"
Ls_mi_duet:     .asciz "Send Clipboard as Duet"
Ls_mi_listen:   .asciz "Listen"
Ls_mi_copy:     .asciz "Copy Last Message"
Ls_mi_open:     .asciz "Open asmtone"
Ls_mi_quit:     .asciz "Quit asmtone"
Ls_mi_about:    .asciz "About asmtone"
Ls_mi_hide:     .asciz "Hide asmtone"
Ls_mi_edit:     .asciz "Edit"
Ls_mi_undo:     .asciz "Undo"
Ls_mi_redo:     .asciz "Redo"
Ls_mi_cut:      .asciz "Cut"
Ls_mi_copy2:    .asciz "Copy"
Ls_mi_paste:    .asciz "Paste"
Ls_mi_selall:   .asciz "Select All"
Ls_mi_window:   .asciz "Window"
Ls_mi_min:      .asciz "Minimize"
Ls_mi_close:    .asciz "Close"
Ls_mi_main:     .asciz "asmtone Window"
Ls_key_none:    .asciz ""
Ls_key_q:       .asciz "q"
Ls_key_h:       .asciz "h"
Ls_key_z:       .asciz "z"
Ls_key_Z:       .asciz "Z"
Ls_key_x:       .asciz "x"
Ls_key_c:       .asciz "c"
Ls_key_v:       .asciz "v"
Ls_key_a:       .asciz "a"
Ls_key_m:       .asciz "m"
Ls_key_w:       .asciz "w"
Ls_key_0:       .asciz "0"
Ls_key_1:       .asciz "1"
Ls_key_2:       .asciz "2"
Ls_key_3:       .asciz "3"
Ls_key_4:       .asciz "4"
Ls_key_5:       .asciz "5"
Ls_key_l:       .asciz "l"
// selectors and classes
Ls_NSApplication:  .asciz "NSApplication"
Ls_NSObject:       .asciz "NSObject"
Ls_NSWindow:       .asciz "NSWindow"
Ls_NSMenu:         .asciz "NSMenu"
Ls_NSMenuItem:     .asciz "NSMenuItem"
Ls_NSStatusBar:    .asciz "NSStatusBar"
Ls_NSSegmented:    .asciz "NSSegmentedControl"
Ls_NSArray:        .asciz "NSArray"
Ls_NSTextField:    .asciz "NSTextField"
Ls_NSButton:       .asciz "NSButton"
Ls_NSLevel:        .asciz "NSLevelIndicator"
Ls_NSTextView:     .asciz "NSTextView"
Ls_NSFont:         .asciz "NSFont"
Ls_NSColor:        .asciz "NSColor"
Ls_NSDictionary:   .asciz "NSDictionary"
Ls_NSAttrString:   .asciz "NSAttributedString"
Ls_NSUserDefaults: .asciz "NSUserDefaults"
Ls_NSTimer:        .asciz "NSTimer"
Ls_NSRunLoop:      .asciz "NSRunLoop"
Ls_NSPasteboard:   .asciz "NSPasteboard"
Ls_AVCapture:      .asciz "AVCaptureDevice"
Ls_sharedApp:      .asciz "sharedApplication"
Ls_setPolicy:      .asciz "setActivationPolicy:"
Ls_setDelegate:    .asciz "setDelegate:"
Ls_run:            .asciz "run"
Ls_new:            .asciz "new"
Ls_alloc:          .asciz "alloc"
Ls_retain:         .asciz "retain"
Ls_release:        .asciz "release"
Ls_autorelease:    .asciz "autorelease"
Ls_initTitle:      .asciz "initWithTitle:"
Ls_addItem:        .asciz "addItem:"
Ls_separator:      .asciz "separatorItem"
Ls_setSubmenu:     .asciz "setSubmenu:"
Ls_setMainMenu:    .asciz "setMainMenu:"
Ls_setWindowsMenu: .asciz "setWindowsMenu:"
Ls_initRect:       .asciz "initWithContentRect:styleMask:backing:defer:"
Ls_setTitle:       .asciz "setTitle:"
Ls_setReleased:    .asciz "setReleasedWhenClosed:"
Ls_setMinSize:     .asciz "setContentMinSize:"
Ls_center:         .asciz "center"
Ls_setAutosave:    .asciz "setFrameAutosaveName:"
Ls_contentView:    .asciz "contentView"
Ls_arrayObjs:      .asciz "arrayWithObjects:count:"
Ls_segWith:        .asciz "segmentedControlWithLabels:trackingMode:target:action:"
Ls_setSelSeg:      .asciz "setSelectedSegment:"
Ls_selSeg:         .asciz "selectedSegment"
Ls_setTextColor:   .asciz "setTextColor:"
Ls_secondaryColor: .asciz "secondaryLabelColor"
Ls_labelColor:     .asciz "labelColor"
Ls_accentColor:    .asciz "controlAccentColor"
Ls_redColor:       .asciz "systemRedColor"
Ls_tfWith:         .asciz "textFieldWithString:"
Ls_setPlaceholder: .asciz "setPlaceholderString:"
Ls_setTarget:      .asciz "setTarget:"
Ls_setAction:      .asciz "setAction:"
Ls_cell:           .asciz "cell"
Ls_setWraps:       .asciz "setWraps:"
Ls_setScrollable:  .asciz "setScrollable:"
Ls_setSingleLine:  .asciz "setUsesSingleLineMode:"
Ls_setFont:        .asciz "setFont:"
Ls_systemFont:     .asciz "systemFontOfSize:"
Ls_monoFont:       .asciz "monospacedSystemFontOfSize:weight:"
Ls_checkbox:       .asciz "checkboxWithTitle:target:action:"
Ls_setState:       .asciz "setState:"
Ls_setLIStyle:     .asciz "setLevelIndicatorStyle:"
Ls_setMaxValue:    .asciz "setMaxValue:"
Ls_setDoubleValue: .asciz "setDoubleValue:"
Ls_scrollableTV:   .asciz "scrollableTextView"
Ls_documentView:   .asciz "documentView"
Ls_setEditable:    .asciz "setEditable:"
Ls_setTCInset:     .asciz "setTextContainerInset:"
Ls_textStorage:    .asciz "textStorage"
Ls_appendAttr:     .asciz "appendAttributedString:"
Ls_initStrAttrs:   .asciz "initWithString:attributes:"
Ls_dictObjs:       .asciz "dictionaryWithObjects:forKeys:count:"
Ls_scrollEnd:      .asciz "scrollToEndOfDocument:"
Ls_setString:      .asciz "setString:"
Ls_systemBar:      .asciz "systemStatusBar"
Ls_statusItem:     .asciz "statusItemWithLength:"
Ls_button:         .asciz "button"
Ls_setTemplate:    .asciz "setTemplate:"
Ls_setImage:       .asciz "setImage:"
Ls_setImagePos:    .asciz "setImagePosition:"
Ls_setMenu:        .asciz "setMenu:"
Ls_setAlpha:       .asciz "setAlphaValue:"
Ls_standardUD:     .asciz "standardUserDefaults"
Ls_integerForKey:  .asciz "integerForKey:"
Ls_boolForKey:     .asciz "boolForKey:"
Ls_setIntForKey:   .asciz "setInteger:forKey:"
Ls_setBoolForKey:  .asciz "setBool:forKey:"
Ls_timerWith:      .asciz "scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:"
Ls_mainRunLoop:    .asciz "mainRunLoop"
Ls_addTimer:       .asciz "addTimer:forMode:"
Ls_makeKey:        .asciz "makeKeyAndOrderFront:"
Ls_activate:       .asciz "activateIgnoringOtherApps:"
Ls_stringValue:    .asciz "stringValue"
Ls_setStringValue: .asciz "setStringValue:"
Ls_UTF8String:     .asciz "UTF8String"
Ls_isActive:       .asciz "isActive"
Ls_dockTile:       .asciz "dockTile"
Ls_setBadge:       .asciz "setBadgeLabel:"
Ls_attention:      .asciz "requestUserAttention:"
Ls_bytes:          .asciz "bytes"
Ls_length:         .asciz "length"
Ls_tag:            .asciz "tag"
Ls_generalPB:      .asciz "generalPasteboard"
Ls_stringForType:  .asciz "stringForType:"
Ls_clearContents:  .asciz "clearContents"
Ls_setStrForType:  .asciz "setString:forType:"
Ls_performAfter:   .asciz "performSelector:withObject:afterDelay:"
Ls_authStatus:     .asciz "authorizationStatusForMediaType:"
Ls_requestAccess:  .asciz "requestAccessForMediaType:completionHandler:"
Ls_performMain:    .asciz "performSelectorOnMainThread:withObject:waitUntilDone:"
Ls_makeFirstResp:  .asciz "makeFirstResponder:"
// actions
Ls_a_send:     .asciz "send:"
Ls_a_mode:     .asciz "modeChanged:"
Ls_a_listen:   .asciz "listenToggled:"
Ls_a_heard:    .asciz "heard:"
Ls_a_played:   .asciz "played:"
Ls_a_unmute:   .asciz "unmute:"
Ls_a_tick:     .asciz "tick:"
Ls_a_copy:     .asciz "copyLast:"
Ls_a_clear:    .asciz "clearLog:"
Ls_a_show:     .asciz "showWindow:"
Ls_a_clip:     .asciz "sendClip:"
Ls_a_textchg:  .asciz "controlTextDidChange:"
Ls_a_start:    .asciz "startListening:"
Ls_a_reopen:   .asciz "applicationShouldHandleReopen:hasVisibleWindows:"
Ls_a_lastwin:  .asciz "applicationShouldTerminateAfterLastWindowClosed:"
Ls_a_active:   .asciz "applicationDidBecomeActive:"
Ls_a_dock:     .asciz "applicationDockMenu:"
Ls_a_about:    .asciz "orderFrontStandardAboutPanel:"
Ls_a_hide:     .asciz "hide:"
Ls_a_quit:     .asciz "terminate:"
Ls_a_undo:     .asciz "undo:"
Ls_a_redo:     .asciz "redo:"
Ls_a_cut:      .asciz "cut:"
Ls_a_copy2:    .asciz "copy:"
Ls_a_paste:    .asciz "paste:"
Ls_a_selall:   .asciz "selectAll:"
Ls_a_min:      .asciz "performMiniaturize:"
Ls_a_close:    .asciz "performClose:"
Ls_t_v:        .asciz "v@:@"
Ls_t_B:        .asciz "B@:@"
Ls_t_BB:       .asciz "B@:@B"
Ls_t_at:       .asciz "@@:@"

.data
.p2align 3
Lmethods:
    .quad Ls_a_send,    _m_send,    Ls_t_v
    .quad Ls_a_mode,    _m_mode,    Ls_t_v
    .quad Ls_a_listen,  _m_listen,  Ls_t_v
    .quad Ls_a_heard,   _m_heard,   Ls_t_v
    .quad Ls_a_played,  _m_played,  Ls_t_v
    .quad Ls_a_unmute,  _m_unmute,  Ls_t_v
    .quad Ls_a_tick,    _m_tick,    Ls_t_v
    .quad Ls_a_copy,    _m_copy,    Ls_t_v
    .quad Ls_a_clear,   _m_clear,   Ls_t_v
    .quad Ls_a_show,    _m_show,    Ls_t_v
    .quad Ls_a_clip,    _m_clip,    Ls_t_v
    .quad Ls_a_textchg, _m_textchg, Ls_t_v
    .quad Ls_a_reopen,  _m_reopen,  Ls_t_BB
    .quad Ls_a_lastwin, _m_no,      Ls_t_B
    .quad Ls_a_active,  _m_active,  Ls_t_v
    .quad Ls_a_dock,    _m_dock,    Ls_t_at
    .quad Ls_a_start,   _m_start,   Ls_t_v
    .quad Ls_a_rec,     _m_recsave, Ls_t_v
    .quad Ls_a_failed,  _m_showfailed, Ls_t_v
    .quad 0
Lmic_block:                               // a global block: ^(BOOL granted) { ... }
    .quad __NSConcreteGlobalBlock
    .word 0x10000000                      // BLOCK_IS_GLOBAL
    .word 0
    .quad _mic_answered
    .quad Lmic_block_desc
Lmic_block_desc:
    .quad 0, 32
Lmode_names:  .quad Ls_piano, Ls_chirp, Ls_fast, Ls_silent, Ls_duet
Lmode_speeds: .quad Ls_sp_piano, Ls_sp_chirp, Ls_sp_fast, Ls_sp_silent, Ls_sp_duet

_g_app:      .quad 0
_g_ctl:      .quad 0
_g_win:      .quad 0
_g_seg:      .quad 0
_g_speed:    .quad 0
_g_field:    .quad 0
_g_play:     .quad 0
_g_est:      .quad 0
_g_listen:   .quad 0
_g_level:    .quad 0
_g_status:   .quad 0
_g_log:      .quad 0
_g_counts:   .quad 0
_g_sitem:    .quad 0
_g_sbutton:  .quad 0
_g_mi_listen:  .quad 0
_g_mi_dlisten: .quad 0
_g_dock:     .quad 0
_g_last:     .quad 0                     // the last message heard (NSString, retained)
_g_mode:     .quad 0
_g_listening: .quad 0
_g_unread:   .quad 0
_g_n_heard:  .quad 0
_g_n_fixed:  .quad 0
_g_n_lost:   .quad 0
_g_hold:     .quad 0                     // ticks to keep a notice in the status line
_g_lastprog: .quad -2                    // what the menu-bar title last showed
_g_meter:    .quad 0                     // float
_g_a_dim:    .quad 0                     // text attributes for the log
_g_a_text:   .quad 0
_g_a_sent:   .quad 0
_g_a_bad:    .quad 0
_g_buf:      .space 512
_g_tbuf:     .space 64
_g_tm:       .space 64
_g_dir:      .space 512
_g_path:     .space 768
_g_fpath:    .space 768                  // last-failed-message.wav

.text
.p2align 2

// ---------------------------------------------------------------------------
// int main(int argc, char **argv)
// ---------------------------------------------------------------------------
.globl _main
_main:
    ENTER 0
    mov  w19, w0
    mov  x20, x1
    bl   _objc_autoreleasePoolPush
    bl   _modem_init
    cmp  w19, #2
    b.lt 1f
    ldr  x0, [x20, #8]
    ADRL x1, Ls_selftest_flag
    bl   _strcmp
    cbnz w0, 1f
    bl   _selftest
    bl   _exit
1:  bl   _build_app
    GET  x0, _g_app
    MSG0 Ls_run
    mov  w0, #0
    LEAVE 0

// ---------------------------------------------------------------------------
// The application: controller, menus, window, menu-bar item, Dock menu, sound
// ---------------------------------------------------------------------------
_build_app:
    ENTER 16
    CLS  Ls_NSApplication
    MSG0 Ls_sharedApp
    PUT  x0, _g_app
    mov  x2, #0                           // regular app: a Dock icon and a menu bar
    MSG1 Ls_setPolicy
    bl   _make_controller
    PUT  x0, _g_ctl
    PUT  x0, _audio_ctl
    mov  x2, x0
    GET  x0, _g_app
    MSG1 Ls_setDelegate
    bl   _make_attrs
    bl   _build_menus
    bl   _build_window
    bl   _build_status_item
    bl   _build_dock_menu
    bl   _audio_init

    CLS  Ls_NSUserDefaults                // last session's mode and listening
    MSG0 Ls_standardUD
    mov  x19, x0
    ADRL x0, Ls_k_mode
    bl   _nsstr
    mov  x2, x0
    mov  x0, x19
    MSG1 Ls_integerForKey
    cmp  x0, #4
    csel x0, x0, xzr, ls
    PUT  x0, _g_mode
    mov  x2, x0
    GET  x0, _g_seg
    MSG1 Ls_setSelSeg
    bl   _update_speed
    bl   _update_est
    bl   _update_counts

    SELX1 Ls_timerWith                    // ten times a second: the meter and status
    mov  x19, x1
    ADRL x0, Ls_a_tick
    bl   _sel_registerName
    mov  x20, x0
    CLS  Ls_NSTimer
    mov  x1, x19
    LDD  d0, Lc_tick
    GET  x2, _g_ctl
    mov  x3, x20
    mov  x4, #0
    mov  x5, #1
    bl   _objc_msgSend
    mov  x20, x0
    CLS  Ls_NSRunLoop                     // keep ticking while a menu is open
    MSG0 Ls_mainRunLoop
    LDGOT x8, _NSRunLoopCommonModes
    ldr  x3, [x8]
    mov  x2, x20
    MSG2 Ls_addTimer

    GET  x0, _g_win
    mov  x2, #0
    MSG1 Ls_makeKey
    GET  x0, _g_app
    mov  x2, #1
    MSG1 Ls_activate
    SELX1 Ls_performAfter                 // the microphone once the window is up: the first
    mov  x19, x1                          // time, macOS asks, and the window shouldn't wait
    ADRL x0, Ls_a_start
    bl   _sel_registerName
    mov  x2, x0
    GET  x0, _g_ctl
    mov  x1, x19
    mov  x3, #0
    LDD  d0, Lc_tick
    bl   _objc_msgSend
    LEAVE 16

// startListening: — Listen as it was left last time (on, the first time)
_m_start:
    ENTER 0
    CLS  Ls_AVCapture                     // never asked yet: ask without blocking the window,
    cbz  x0, 1f                           // and come back here with the answer
    LDGOT x8, _AVMediaTypeAudio
    ldr  x2, [x8]
    MSG1 Ls_authStatus
    cbnz x0, 1f
    CLS  Ls_AVCapture
    LDGOT x8, _AVMediaTypeAudio
    ldr  x2, [x8]
    ADRL x3, Lmic_block
    MSG2 Ls_requestAccess
    LEAVE 0
1:  CLS  Ls_NSUserDefaults
    MSG0 Ls_standardUD
    mov  x19, x0
    ADRL x0, Ls_k_listenoff
    bl   _nsstr
    mov  x2, x0
    mov  x0, x19
    MSG1 Ls_boolForKey
    and  x0, x0, #1
    eor  x0, x0, #1
    bl   _set_listen
    LEAVE 0

// the microphone question was answered (on some other thread): try again on the main one
_mic_answered:
    ENTER 0
    ADRL x0, Ls_a_start
    bl   _sel_registerName
    mov  x2, x0
    GET  x0, _g_ctl
    mov  x3, #0
    mov  x4, #0
    ADRL x1, Ls_performMain
    bl   _msg3
    LEAVE 0

// id _make_controller(void) — ATController, built from the method table
_make_controller:
    ENTER 0
    CLS  Ls_NSObject
    ADRL x1, Ls_ctl_name
    mov  x2, #0
    bl   _objc_allocateClassPair
    mov  x19, x0
    ADRL x20, Lmethods
1:  ldr  x0, [x20]
    cbz  x0, 2f
    bl   _sel_registerName
    mov  x1, x0
    mov  x0, x19
    ldr  x2, [x20, #8]
    ldr  x3, [x20, #16]
    bl   _class_addMethod
    add  x20, x20, #24
    b    1b
2:  mov  x0, x19
    bl   _objc_registerClassPair
    mov  x0, x19
    MSG0 Ls_new
    LEAVE 0

// text attributes for the log: {font, colour}
_make_attrs:
    ENTER 16
    SELX1 Ls_monoFont
    mov  x19, x1
    CLS  Ls_NSFont
    mov  x1, x19
    LDD  d0, Lc_f12
    LDD  d1, Lc_zero
    bl   _objc_msgSend
    mov  x19, x0                          // monospaced, for the times
    SELX1 Ls_systemFont
    mov  x20, x1
    CLS  Ls_NSFont
    mov  x1, x20
    LDD  d0, Lc_f13
    bl   _objc_msgSend
    mov  x20, x0                          // the messages
    mov  x0, x19
    ADRL x1, Ls_secondaryColor
    bl   _attr_dict
    PUT  x0, _g_a_dim
    mov  x0, x20
    ADRL x1, Ls_labelColor
    bl   _attr_dict
    PUT  x0, _g_a_text
    mov  x0, x20
    ADRL x1, Ls_accentColor
    bl   _attr_dict
    PUT  x0, _g_a_sent
    mov  x0, x20
    ADRL x1, Ls_redColor
    bl   _attr_dict
    PUT  x0, _g_a_bad
    LEAVE 16

// id _attr_dict(id font, const char *colorSelector) — retained
_attr_dict:
    ENTER 32
    mov  x19, x0
    mov  x20, x1
    CLS  Ls_NSColor
    mov  x1, x20
    bl   _msg0
    str  x19, [sp, #96]                   // objects
    str  x0, [sp, #104]
    LDGOT x8, _NSFontAttributeName
    ldr  x9, [x8]
    str  x9, [sp, #112]                   // keys
    LDGOT x8, _NSForegroundColorAttributeName
    ldr  x9, [x8]
    str  x9, [sp, #120]
    CLS  Ls_NSDictionary
    add  x2, sp, #96
    add  x3, sp, #112
    mov  x4, #2
    MSG3 Ls_dictObjs
    MSG0 Ls_retain
    LEAVE 32

// the main menu: app, Edit (so typing, copy and paste work), Window
_build_menus:
    ENTER 16
    CLS  Ls_NSMenu
    MSG0 Ls_new
    mov  x19, x0                          // the bar

    CLS  Ls_NSMenu                        // asmtone
    MSG0 Ls_new
    mov  x20, x0
    mov  x0, x20
    ADRL x1, Ls_mi_about
    ADRL x2, Ls_a_about
    ADRL x3, Ls_key_none
    mov  x4, #0
    mov  x5, #0
    bl   _menu_item
    mov  x0, x20
    ADRL x1, Ls_mi_rec
    ADRL x2, Ls_a_rec
    ADRL x3, Ls_key_s
    GET  x4, _g_ctl
    mov  x5, #0
    bl   _menu_item
    mov  x0, x20
    ADRL x1, Ls_mi_failed
    ADRL x2, Ls_a_failed
    ADRL x3, Ls_key_none
    GET  x4, _g_ctl
    mov  x5, #0
    bl   _menu_item
    mov  x0, x20
    bl   _add_separator
    mov  x0, x20
    ADRL x1, Ls_mi_hide
    ADRL x2, Ls_a_hide
    ADRL x3, Ls_key_h
    mov  x4, #0
    mov  x5, #0
    bl   _menu_item
    mov  x0, x20
    ADRL x1, Ls_mi_quit
    ADRL x2, Ls_a_quit
    ADRL x3, Ls_key_q
    mov  x4, #0
    mov  x5, #0
    bl   _menu_item
    mov  x0, x19
    ADRL x1, Ls_title
    mov  x2, #0
    ADRL x3, Ls_key_none
    mov  x4, #0
    mov  x5, #0
    bl   _menu_item
    mov  x2, x20
    MSG1 Ls_setSubmenu

    ADRL x0, Ls_mi_edit                   // Edit
    bl   _titled_menu
    mov  x20, x0
    mov  x0, x20
    ADRL x1, Ls_mi_undo
    ADRL x2, Ls_a_undo
    ADRL x3, Ls_key_z
    mov  x4, #0
    mov  x5, #0
    bl   _menu_item
    mov  x0, x20
    ADRL x1, Ls_mi_redo
    ADRL x2, Ls_a_redo
    ADRL x3, Ls_key_Z
    mov  x4, #0
    mov  x5, #0
    bl   _menu_item
    mov  x0, x20
    bl   _add_separator
    mov  x0, x20
    ADRL x1, Ls_mi_cut
    ADRL x2, Ls_a_cut
    ADRL x3, Ls_key_x
    mov  x4, #0
    mov  x5, #0
    bl   _menu_item
    mov  x0, x20
    ADRL x1, Ls_mi_copy2
    ADRL x2, Ls_a_copy2
    ADRL x3, Ls_key_c
    mov  x4, #0
    mov  x5, #0
    bl   _menu_item
    mov  x0, x20
    ADRL x1, Ls_mi_paste
    ADRL x2, Ls_a_paste
    ADRL x3, Ls_key_v
    mov  x4, #0
    mov  x5, #0
    bl   _menu_item
    mov  x0, x20
    ADRL x1, Ls_mi_selall
    ADRL x2, Ls_a_selall
    ADRL x3, Ls_key_a
    mov  x4, #0
    mov  x5, #0
    bl   _menu_item
    mov  x0, x19
    ADRL x1, Ls_mi_edit
    mov  x2, #0
    ADRL x3, Ls_key_none
    mov  x4, #0
    mov  x5, #0
    bl   _menu_item
    mov  x2, x20
    MSG1 Ls_setSubmenu

    ADRL x0, Ls_mi_window                 // Window
    bl   _titled_menu
    mov  x20, x0
    mov  x0, x20
    ADRL x1, Ls_mi_min
    ADRL x2, Ls_a_min
    ADRL x3, Ls_key_m
    mov  x4, #0
    mov  x5, #0
    bl   _menu_item
    mov  x0, x20
    ADRL x1, Ls_mi_close
    ADRL x2, Ls_a_close
    ADRL x3, Ls_key_w
    mov  x4, #0
    mov  x5, #0
    bl   _menu_item
    mov  x0, x20
    bl   _add_separator
    mov  x0, x20
    ADRL x1, Ls_mi_main
    ADRL x2, Ls_a_show
    ADRL x3, Ls_key_0
    GET  x4, _g_ctl
    mov  x5, #0
    bl   _menu_item
    mov  x0, x19
    ADRL x1, Ls_mi_window
    mov  x2, #0
    ADRL x3, Ls_key_none
    mov  x4, #0
    mov  x5, #0
    bl   _menu_item
    mov  x2, x20
    MSG1 Ls_setSubmenu

    GET  x0, _g_app
    mov  x2, x19
    MSG1 Ls_setMainMenu
    GET  x0, _g_app
    mov  x2, x20
    MSG1 Ls_setWindowsMenu
    LEAVE 16

// id _titled_menu(const char *title)
_titled_menu:
    ENTER 0
    bl   _nsstr
    mov  x19, x0
    CLS  Ls_NSMenu
    MSG0 Ls_alloc
    mov  x2, x19
    MSG1 Ls_initTitle
    MSG0 Ls_autorelease
    LEAVE 0

// void _add_separator(id menu)
_add_separator:
    ENTER 0
    mov  x19, x0
    CLS  Ls_NSMenuItem
    MSG0 Ls_separator
    mov  x2, x0
    mov  x0, x19
    MSG1 Ls_addItem
    LEAVE 0

// the three "Send Clipboard as ..." items and Listen, into a menu; returns the Listen item
_send_items:
    ENTER 0
    mov  x19, x0
    mov  x0, x19
    ADRL x1, Ls_mi_piano
    ADRL x2, Ls_a_clip
    ADRL x3, Ls_key_1
    GET  x4, _g_ctl
    mov  x5, #0
    bl   _menu_item
    mov  x0, x19
    ADRL x1, Ls_mi_chirp
    ADRL x2, Ls_a_clip
    ADRL x3, Ls_key_2
    GET  x4, _g_ctl
    mov  x5, #1
    bl   _menu_item
    mov  x0, x19
    ADRL x1, Ls_mi_fast
    ADRL x2, Ls_a_clip
    ADRL x3, Ls_key_3
    GET  x4, _g_ctl
    mov  x5, #2
    bl   _menu_item
    mov  x0, x19
    ADRL x1, Ls_mi_silent
    ADRL x2, Ls_a_clip
    ADRL x3, Ls_key_4
    GET  x4, _g_ctl
    mov  x5, #3
    bl   _menu_item
    mov  x0, x19
    ADRL x1, Ls_mi_duet
    ADRL x2, Ls_a_clip
    ADRL x3, Ls_key_5
    GET  x4, _g_ctl
    mov  x5, #4
    bl   _menu_item
    mov  x0, x19
    bl   _add_separator
    mov  x0, x19
    ADRL x1, Ls_mi_listen
    ADRL x2, Ls_a_listen
    ADRL x3, Ls_key_l
    GET  x4, _g_ctl
    mov  x5, #0
    bl   _menu_item
    LEAVE 0

// ---------------------------------------------------------------------------
// The window
// ---------------------------------------------------------------------------
_build_window:
    ENTER 48
    CLS  Ls_NSWindow
    MSG0 Ls_alloc
    mov  x19, x0
    SELX1 Ls_initRect
    mov  x0, x19
    ADRL x9, Lc_win
    ldp  d0, d1, [x9]
    ldp  d2, d3, [x9, #16]
    mov  x2, #15                          // titled, closable, miniaturizable, resizable
    mov  x3, #2
    mov  x4, #0
    bl   _objc_msgSend
    mov  x19, x0
    PUT  x19, _g_win
    ADRL x0, Ls_title
    bl   _nsstr
    mov  x2, x0
    mov  x0, x19
    MSG1 Ls_setTitle
    mov  x0, x19
    mov  x2, #0
    MSG1 Ls_setReleased
    SELX1 Ls_setMinSize
    mov  x0, x19
    ADRL x9, Lc_minsz
    ldp  d0, d1, [x9]
    bl   _objc_msgSend
    mov  x0, x19
    MSG0 Ls_center
    ADRL x0, Ls_k_frame
    bl   _nsstr
    mov  x2, x0
    mov  x0, x19
    MSG1 Ls_setAutosave
    mov  x0, x19
    MSG0 Ls_contentView
    mov  x20, x0                          // x20 = content view

    // mode: Piano | Chirp | Fast
    ADRL x0, Ls_piano
    bl   _nsstr
    str  x0, [sp, #96]
    ADRL x0, Ls_chirp
    bl   _nsstr
    str  x0, [sp, #104]
    ADRL x0, Ls_fast
    bl   _nsstr
    str  x0, [sp, #112]
    ADRL x0, Ls_silent
    bl   _nsstr
    str  x0, [sp, #120]
    ADRL x0, Ls_duet
    bl   _nsstr
    str  x0, [sp, #128]
    CLS  Ls_NSArray
    add  x2, sp, #96
    mov  x3, #5
    MSG2 Ls_arrayObjs
    mov  x21, x0
    ADRL x0, Ls_a_mode
    bl   _sel_registerName
    mov  x22, x0
    CLS  Ls_NSSegmented
    mov  x2, x21
    mov  x3, #0
    GET  x4, _g_ctl
    mov  x5, x22
    MSG4 Ls_segWith
    mov  x1, x20
    mov  x2, #AR_MINY
    FRAME 0
    bl   _place
    PUT  x0, _g_seg

    ADRL x0, Ls_sp_piano                  // speed
    mov  x1, x20
    mov  x2, #(AR_MINX + AR_MINY)
    FRAME 1
    bl   _label
    PUT  x0, _g_speed
    bl   _dim

    ADRL x0, Ls_key_none
    bl   _nsstr
    mov  x21, x0
    CLS  Ls_NSTextField
    mov  x2, x21
    MSG1 Ls_tfWith
    mov  x21, x0
    PUT  x21, _g_field
    ADRL x0, Ls_placeholder
    bl   _nsstr
    mov  x2, x0
    mov  x0, x21
    MSG1 Ls_setPlaceholder
    mov  x0, x21
    GET  x2, _g_ctl
    MSG1 Ls_setTarget
    ADRL x0, Ls_a_send
    bl   _sel_registerName
    mov  x2, x0
    mov  x0, x21
    MSG1 Ls_setAction
    mov  x0, x21
    GET  x2, _g_ctl
    MSG1 Ls_setDelegate
    mov  x0, x21
    mov  x2, #0
    MSG1 Ls_setSingleLine
    mov  x0, x21
    MSG0 Ls_cell
    mov  x22, x0
    mov  x2, #1
    MSG1 Ls_setWraps
    mov  x0, x22
    mov  x2, #0
    MSG1 Ls_setScrollable
    SELX1 Ls_systemFont
    mov  x22, x1
    CLS  Ls_NSFont
    mov  x1, x22
    LDD  d0, Lc_f15
    bl   _objc_msgSend
    mov  x2, x0
    mov  x0, x21
    MSG1 Ls_setFont
    mov  x0, x21
    mov  x1, x20
    mov  x2, #(AR_W + AR_MINY)
    FRAME 2
    bl   _place

    ADRL x0, Ls_play                      // Play
    ADRL x1, Ls_a_send
    GET  x2, _g_ctl
    mov  x3, x20
    mov  x4, #AR_MINY
    FRAME 3
    bl   _button
    PUT  x0, _g_play

    ADRL x0, Ls_est_empty                 // how long it will take
    mov  x1, x20
    mov  x2, #(AR_W + AR_MINY)
    FRAME 4
    bl   _label
    PUT  x0, _g_est
    bl   _dim

    ADRL x0, Ls_listen                    // Listen [meter] status
    bl   _nsstr
    mov  x21, x0
    ADRL x0, Ls_a_listen
    bl   _sel_registerName
    mov  x22, x0
    CLS  Ls_NSButton
    mov  x2, x21
    GET  x3, _g_ctl
    mov  x4, x22
    MSG3 Ls_checkbox
    mov  x1, x20
    mov  x2, #AR_MINY
    FRAME 5
    bl   _place
    PUT  x0, _g_listen

    CLS  Ls_NSLevel
    MSG0 Ls_new
    mov  x21, x0
    MSG0 Ls_autorelease
    mov  x0, x21
    mov  x2, #1                           // continuous capacity
    MSG1 Ls_setLIStyle
    SELX1 Ls_setMaxValue
    mov  x0, x21
    LDD  d0, Lc_one
    bl   _objc_msgSend
    mov  x0, x21
    mov  x1, x20
    mov  x2, #AR_MINY
    FRAME 6
    bl   _place
    PUT  x0, _g_level

    ADRL x0, Ls_st_off
    mov  x1, x20
    mov  x2, #(AR_W + AR_MINY)
    FRAME 7
    bl   _label
    PUT  x0, _g_status
    bl   _dim

    CLS  Ls_NSTextView                    // what was heard (and sent)
    MSG0 Ls_scrollableTV
    mov  x21, x0
    mov  x1, x20
    mov  x2, #(AR_W + AR_H)
    FRAME 8
    bl   _place
    mov  x0, x21
    MSG0 Ls_documentView
    mov  x22, x0
    PUT  x22, _g_log
    mov  x0, x22
    mov  x2, #0
    MSG1 Ls_setEditable
    SELX1 Ls_setTCInset
    mov  x0, x22
    LDD  d0, Lc_tick
    fmov d0, #4.0
    fmov d1, #6.0
    bl   _objc_msgSend

    ADRL x0, Ls_copylast                  // Copy Last, Clear, counts
    ADRL x1, Ls_a_copy
    GET  x2, _g_ctl
    mov  x3, x20
    mov  x4, #AR_MAXY
    FRAME 9
    bl   _button
    ADRL x0, Ls_clear
    ADRL x1, Ls_a_clear
    GET  x2, _g_ctl
    mov  x3, x20
    mov  x4, #AR_MAXY
    FRAME 10
    bl   _button
    ADRL x0, Ls_key_none
    mov  x1, x20
    mov  x2, #(AR_W + AR_MAXY)
    FRAME 11
    bl   _label
    PUT  x0, _g_counts
    bl   _dim

    GET  x0, _g_win                       // start in the message field
    GET  x2, _g_field
    MSG1 Ls_makeFirstResp
    LEAVE 48

// _dim(id label) — secondary text colour
_dim:
    ENTER 0
    mov  x19, x0
    CLS  Ls_NSColor
    MSG0 Ls_secondaryColor
    mov  x2, x0
    mov  x0, x19
    MSG1 Ls_setTextColor
    LEAVE 0

// the menu-bar item: piano keys, a percentage while a message is coming in
_build_status_item:
    ENTER 0
    CLS  Ls_NSStatusBar
    MSG0 Ls_systemBar
    mov  x19, x0
    SELX1 Ls_statusItem
    mov  x0, x19
    LDD  d0, Lc_varlen
    bl   _objc_msgSend
    MSG0 Ls_retain
    PUT  x0, _g_sitem
    MSG0 Ls_button
    mov  x20, x0
    PUT  x20, _g_sbutton
    ADRL x0, Ls_sym_main
    bl   _symbol
    cbnz x0, 1f
    ADRL x0, Ls_sym_alt
    bl   _symbol
    cbz  x0, 2f
1:  mov  x21, x0
    mov  x2, #1
    MSG1 Ls_setTemplate
    mov  x0, x20
    mov  x2, x21
    MSG1 Ls_setImage
    mov  x0, x20
    mov  x2, #2                           // image left of the title
    MSG1 Ls_setImagePos
    b    3f
2:  ADRL x0, Ls_title
    bl   _nsstr
    mov  x2, x0
    mov  x0, x20
    MSG1 Ls_setTitle
3:  CLS  Ls_NSMenu
    MSG0 Ls_new
    mov  x19, x0
    bl   _send_items
    PUT  x0, _g_mi_listen
    mov  x0, x19
    ADRL x1, Ls_mi_copy
    ADRL x2, Ls_a_copy
    ADRL x3, Ls_key_none
    GET  x4, _g_ctl
    mov  x5, #0
    bl   _menu_item
    mov  x0, x19
    ADRL x1, Ls_mi_rec
    ADRL x2, Ls_a_rec
    ADRL x3, Ls_key_none
    GET  x4, _g_ctl
    mov  x5, #0
    bl   _menu_item
    mov  x0, x19
    ADRL x1, Ls_mi_failed
    ADRL x2, Ls_a_failed
    ADRL x3, Ls_key_none
    GET  x4, _g_ctl
    mov  x5, #0
    bl   _menu_item
    mov  x0, x19
    bl   _add_separator
    mov  x0, x19
    ADRL x1, Ls_mi_open
    ADRL x2, Ls_a_show
    ADRL x3, Ls_key_none
    GET  x4, _g_ctl
    mov  x5, #0
    bl   _menu_item
    mov  x0, x19
    ADRL x1, Ls_mi_quit
    ADRL x2, Ls_a_quit
    ADRL x3, Ls_key_none
    mov  x4, #0
    mov  x5, #0
    bl   _menu_item
    GET  x0, _g_sitem
    mov  x2, x19
    MSG1 Ls_setMenu
    LEAVE 0

// the Dock icon's menu (right-click): the same send items and Listen
_build_dock_menu:
    ENTER 0
    CLS  Ls_NSMenu
    MSG0 Ls_new
    mov  x19, x0
    PUT  x19, _g_dock
    bl   _send_items
    PUT  x0, _g_mi_dlisten
    LEAVE 0

// ---------------------------------------------------------------------------
// Labels that change
// ---------------------------------------------------------------------------
_update_speed:
    ENTER 0
    GET  x9, _g_mode
    ADRL x10, Lmode_speeds
    ldr  x0, [x10, x9, lsl #3]
    bl   _nsstr
    mov  x2, x0
    GET  x0, _g_speed
    MSG1 Ls_setStringValue
    LEAVE 0

// how long the message in the field will take, or why it can't go
_update_est:
    ENTER 16
    bl   _field_cstr
    mov  x19, x0
    bl   _strlen
    mov  x20, x0
    cbnz x20, 1f
    ADRL x0, Ls_est_empty
    b    3f
1:  mov  x0, x19                         // the size it packs to
    mov  x1, x20
    bl   _pack_len
    mov  x22, x0
    GET  x0, _g_mode
    bl   _tx_maxlen
    mov  x21, x0
    cmp  x22, x21
    b.ls 2f
    str  x20, [sp]                        // too long
    GET  x9, _g_mode
    ADRL x10, Lmode_names
    ldr  x9, [x10, x9, lsl #3]
    str  x9, [sp, #8]
    ADRL x0, _g_buf
    mov  x1, #512
    ADRL x2, Ls_est_long
    bl   _snprintf
    ADRL x0, _g_buf
    b    3f
2:  GET  x0, _g_mode
    mov  x1, x22
    bl   _tx_samples
    ucvtf d0, x0
    LDD  d1, Lc_sr
    fdiv d0, d0, d1
    str  x20, [sp]
    str  d0, [sp, #8]
    ADRL x0, _g_buf
    mov  x1, #512
    ADRL x2, Ls_est_fmt
    bl   _snprintf
    ADRL x0, _g_buf
3:  bl   _nsstr
    mov  x2, x0
    GET  x0, _g_est
    MSG1 Ls_setStringValue
    LEAVE 16

// const char *_field_cstr(void) — the message field as UTF-8
_field_cstr:
    ENTER 0
    GET  x0, _g_field
    MSG0 Ls_stringValue
    MSG0 Ls_UTF8String
    cbnz x0, 1f
    ADRL x0, Ls_key_none
1:  LEAVE 0

// _notice(const char *text) — show in the status line for a few seconds
_notice:
    ENTER 0
    bl   _nsstr
    mov  x2, x0
    GET  x0, _g_status
    MSG1 Ls_setStringValue
    mov  x9, #50
    PUT  x9, _g_hold
    LEAVE 0

_update_counts:
    ENTER 0
    GET  x9, _g_n_heard
    str  x9, [sp]
    GET  x9, _g_n_fixed
    str  x9, [sp, #8]
    GET  x9, _g_n_lost
    str  x9, [sp, #16]
    ADRL x0, _g_buf
    mov  x1, #512
    ADRL x2, Ls_counts
    bl   _snprintf
    ADRL x0, _g_buf
    bl   _nsstr
    mov  x2, x0
    GET  x0, _g_counts
    MSG1 Ls_setStringValue
    LEAVE 0

// _set_listen(long on)
_set_listen:
    ENTER 0
    mov  x19, x0
    cbz  x19, 2f
    bl   _mic_allowed
    cbnz x0, 1f
    ADRL x0, Ls_st_mic
    bl   _notice
    mov  x19, #0
    b    2f
1:  mov  x0, #1
    bl   _audio_listen
    cbz  x0, 3f
    str  x0, [sp]
    ADRL x0, _g_buf
    mov  x1, #512
    ADRL x2, Ls_st_err
    bl   _snprintf
    ADRL x0, _g_buf
    bl   _notice
    mov  x19, #0
2:  mov  x0, #0
    bl   _audio_listen
3:  PUT  x19, _g_listening
    GET  x0, _g_listen
    mov  x2, x19
    MSG1 Ls_setState
    GET  x0, _g_mi_listen
    mov  x2, x19
    MSG1 Ls_setState
    GET  x0, _g_mi_dlisten
    mov  x2, x19
    MSG1 Ls_setState
    SELX1 Ls_setAlpha                     // the menu-bar icon dims while not listening
    GET  x0, _g_sbutton
    LDD  d0, Lc_one
    LDD  d1, Lc_dim
    cmp  x19, #0
    fcsel d0, d0, d1, ne
    bl   _objc_msgSend
    LEAVE 0

// long _mic_allowed(void) — 0 if the person has turned the microphone off for us
_mic_allowed:
    ENTER 0
    CLS  Ls_AVCapture
    cbz  x0, 1f
    LDGOT x8, _AVMediaTypeAudio
    ldr  x2, [x8]
    MSG1 Ls_authStatus
    cmp  x0, #1                           // restricted
    b.eq 2f
    cmp  x0, #2                           // denied
    b.eq 2f
1:  mov  x0, #1
    LEAVE 0
2:  mov  x0, #0
    LEAVE 0

// _log_line(long kind, long mode, const void *text, long len, long fixed)
_log_line:
    ENTER 32
    mov  x19, x0
    mov  x20, x1
    mov  x21, x2
    mov  x22, x3
    str  x4, [sp, #96]
    add  x0, sp, #104                     // HH:MM:SS
    bl   _time
    add  x0, sp, #104
    ADRL x1, _g_tm
    bl   _localtime_r
    ADRL x0, _g_tbuf
    mov  x1, #64
    ADRL x2, Ls_time
    ADRL x3, _g_tm
    bl   _strftime
    ADRL x9, _g_tbuf
    str  x9, [sp]
    ADRL x10, Lmode_names
    ldr  x9, [x10, x20, lsl #3]
    str  x9, [sp, #8]
    ADRL x0, _g_buf
    mov  x1, #512
    ADRL x2, Ls_pre_heard
    cmp  x19, #K_SENT
    b.ne 1f
    ADRL x2, Ls_pre_sent
1:  bl   _snprintf
    ADRL x0, _g_buf
    bl   _nsstr
    GET  x1, _g_a_dim
    bl   _log_append
    mov  x0, x21                          // the text itself
    mov  x1, x22
    mov  x2, #4                           // UTF-8
    bl   _nsstr_bytes
    cbnz x0, 2f
    mov  x0, x21
    mov  x1, x22
    mov  x2, #5                           // or Latin-1 if it got mangled
    bl   _nsstr_bytes
2:  GET  x1, _g_a_text
    cmp  x19, #K_SENT
    b.ne 3f
    GET  x1, _g_a_sent
3:  cmp  x19, #K_BAD
    b.ne 4f
    GET  x1, _g_a_bad
4:  bl   _log_append
    ldr  x9, [sp, #96]
    cbz  x9, 5f
    str  x9, [sp]
    ADRL x0, _g_buf
    mov  x1, #512
    ADRL x2, Ls_fixed_fmt
    bl   _snprintf
    ADRL x0, _g_buf
    bl   _nsstr
    GET  x1, _g_a_dim
    bl   _log_append
5:  ADRL x0, Ls_nl
    bl   _nsstr
    GET  x1, _g_a_dim
    bl   _log_append
    GET  x0, _g_log
    mov  x2, #0
    MSG1 Ls_scrollEnd
    LEAVE 32

// _log_append(NSString *s, NSDictionary *attrs)
_log_append:
    ENTER 0
    cbz  x0, 1f
    mov  x19, x0
    mov  x20, x1
    CLS  Ls_NSAttrString
    MSG0 Ls_alloc
    mov  x2, x19
    mov  x3, x20
    MSG2 Ls_initStrAttrs
    MSG0 Ls_autorelease
    mov  x19, x0
    GET  x0, _g_log
    MSG0 Ls_textStorage
    mov  x2, x19
    MSG1 Ls_appendAttr
1:  LEAVE 0

// ---------------------------------------------------------------------------
// ATController methods: (self, _cmd, arg)
// ---------------------------------------------------------------------------

// send: — Play (or Stop while playing)
_m_send:
    ENTER 16
    ADRL x9, _tx_active
    ldr  x9, [x9]
    cbz  x9, 1f
    bl   _audio_stop
    bl   _played_ui
    LEAVE 16
1:  bl   _field_cstr
    mov  x19, x0
    bl   _strlen
    mov  x20, x0
    cbz  x20, Lsend_beep
    mov  x0, x19
    mov  x1, x20
    bl   _pack_len
    mov  x21, x0
    GET  x0, _g_mode
    bl   _tx_maxlen
    cmp  x21, x0
    b.ls 2f
    GET  x9, _g_mode                      // too long
    ADRL x10, Lmode_names
    ldr  x9, [x10, x9, lsl #3]
    str  x9, [sp]
    ADRL x0, _g_buf
    mov  x1, #512
    ADRL x2, Ls_st_long
    bl   _snprintf
    ADRL x0, _g_buf
    bl   _notice
    bl   _m_show
    b    Lsend_beep
2:  GET  x0, _g_mode
    mov  x1, x19
    mov  x2, x20
    bl   _tx_render
    cbz  x0, Lsend_beep
    bl   _audio_play
    cbz  x0, Lsend_beep
    ADRL x0, Ls_stop
    bl   _nsstr
    mov  x2, x0
    GET  x0, _g_play
    MSG1 Ls_setTitle
    mov  x0, #K_SENT
    GET  x1, _g_mode
    mov  x2, x19
    mov  x3, x20
    mov  x4, #0
    bl   _log_line
    LEAVE 16
Lsend_beep:
    bl   _NSBeep
    LEAVE 16

// played: — the speaker is done
_m_played:
    ENTER 0
    bl   _played_ui
    LEAVE 0

_played_ui:
    ENTER 0
    ADRL x0, Ls_play
    bl   _nsstr
    mov  x2, x0
    GET  x0, _g_play
    MSG1 Ls_setTitle
    SELX1 Ls_performAfter                 // listen again once the room has gone quiet
    mov  x19, x1
    ADRL x0, Ls_a_unmute
    bl   _sel_registerName
    mov  x2, x0
    GET  x0, _g_ctl
    mov  x1, x19
    mov  x3, #0
    LDD  d0, Lc_unmute
    bl   _objc_msgSend
    LEAVE 0

_m_unmute:
    ADRL x9, _tx_active
    ldr  x9, [x9]
    cbnz x9, 1f
    ADRL x9, _rx_mute
    str  xzr, [x9]
1:  ret

// modeChanged:
_m_mode:
    ENTER 0
    GET  x0, _g_seg
    MSG0 Ls_selSeg
    cmp  x0, #4
    csel x0, x0, xzr, ls
    PUT  x0, _g_mode
    mov  x19, x0
    CLS  Ls_NSUserDefaults
    MSG0 Ls_standardUD
    mov  x20, x0
    ADRL x0, Ls_k_mode
    bl   _nsstr
    mov  x3, x0
    mov  x0, x20
    mov  x2, x19
    MSG2 Ls_setIntForKey
    bl   _update_speed
    bl   _update_est
    LEAVE 0

// controlTextDidChange:
_m_textchg:
    ENTER 0
    bl   _update_est
    LEAVE 0

// listenToggled: (the checkbox or a menu item)
_m_listen:
    ENTER 0
    GET  x19, _g_listening
    eor  x19, x19, #1
    mov  x0, x19
    bl   _set_listen
    CLS  Ls_NSUserDefaults                // remember what was asked for (not whether it worked)
    MSG0 Ls_standardUD
    mov  x20, x0
    ADRL x0, Ls_k_listenoff
    bl   _nsstr
    mov  x3, x0
    mov  x0, x20
    eor  x2, x19, #1
    MSG2 Ls_setBoolForKey
    LEAVE 0

// heard: NSData from the receiver
_m_heard:
    ENTER 16
    mov  x19, x2
    mov  x0, x19
    MSG0 Ls_length
    mov  x20, x0
    cmp  x20, #4
    b.lo 9f
    mov  x0, x19
    MSG0 Ls_bytes
    mov  x21, x0
    ldrb w22, [x21]                       // mode
    cmp  w22, #4
    b.hi 9f
    ldrb w9, [x21, #2]
    cbz  w9, 1f
    GET  x10, _g_n_lost                   // too damaged, or the length unreadable
    add  x10, x10, #1
    PUT  x10, _g_n_lost
    ADRL x23, Ls_bad_text
    cmp  w9, #2
    b.ne 0f
    ADRL x23, Ls_nohdr_text
0:  mov  x0, x23
    bl   _strlen
    mov  x3, x0
    mov  x0, #K_BAD
    mov  x1, x22
    mov  x2, x23
    mov  x4, #0
    bl   _log_line
    bl   _save_failed                     // keep the sound, for Show Last Failed Message
    cmp  x22, #MODE_FAST                  // Fast and Duet need the Macs close
    b.eq 0f
    cmp  x22, #MODE_DUET
    b.ne 8f
0:
    ADRL x0, Ls_fast_far
    bl   _notice
    b    8f
1:  GET  x9, _g_n_heard
    add  x9, x9, #1
    PUT  x9, _g_n_heard
    ldrb w23, [x21, #1]                   // bytes repaired
    cbz  w23, 2f
    GET  x9, _g_n_fixed
    add  x9, x9, #1
    PUT  x9, _g_n_fixed
2:  mov  x0, #K_HEARD
    mov  x1, x22
    add  x2, x21, #4
    sub  x3, x20, #4
    mov  x4, x23
    bl   _log_line
    add  x0, x21, #4                      // remember it for Copy Last
    sub  x1, x20, #4
    mov  x2, #4
    bl   _nsstr_bytes
    cbz  x0, 3f
    MSG0 Ls_retain
    mov  x24, x0
    GET  x0, _g_last
    cbz  x0, 4f
    MSG0 Ls_release
4:  PUT  x24, _g_last
3:  GET  x0, _g_app                       // a badge on the Dock icon if nobody's looking
    MSG0 Ls_isActive
    and  x0, x0, #1
    cbnz x0, 8f
    GET  x9, _g_unread
    add  x9, x9, #1
    PUT  x9, _g_unread
    str  x9, [sp]
    ADRL x0, _g_buf
    mov  x1, #512
    ADRL x2, Ls_badge
    bl   _snprintf
    GET  x0, _g_app
    MSG0 Ls_dockTile
    mov  x19, x0
    ADRL x0, _g_buf
    bl   _nsstr
    mov  x2, x0
    mov  x0, x19
    MSG1 Ls_setBadge
    GET  x0, _g_app
    mov  x2, #10                          // NSInformationalRequest: one bounce
    MSG1 Ls_attention
8:  bl   _update_counts
9:  LEAVE 16

// applicationDidBecomeActive: — clear the badge
_m_active:
    ENTER 0
    PUT  xzr, _g_unread
    GET  x0, _g_app
    MSG0 Ls_dockTile
    mov  x2, #0
    MSG1 Ls_setBadge
    LEAVE 0

// tick: — the level meter, the status line and the menu-bar percentage
_m_tick:
    ENTER 32
    stp  d8, d9, [sp, #96]
    bl   _rx_peak_take
    fmov s8, s0
    GET  x9, _g_listening
    cbnz x9, 0f
    fmov s8, wzr
0:  LDS  s1, Lk_clip                      // overloading (and not just hearing ourselves)?
    fcmp s8, s1
    b.lt 1f
    ADRL x9, _rx_mute
    ldr  x9, [x9]
    cbnz x9, 1f
    ADRL x0, Ls_st_clip
    bl   _notice
1:  LDS  s1, Lk_tiny                      // 0 at -60 dB, 1 at 0 dB
    fmax s0, s8, s1
    CALLC log10f
    LDS  s1, Lk_db
    fmul s0, s0, s1
    LDS  s1, Lk_db60
    fadd s0, s0, s1
    LDS  s1, Lk_inv60
    fmul s0, s0, s1
    fmov s1, wzr
    fmax s0, s0, s1
    fmov s1, #1.0
    fmin s0, s0, s1
    ADRL x9, _g_meter                     // falls back slowly
    ldr  s1, [x9]
    LDS  s2, Lk_fall
    fsub s1, s1, s2
    fmax s0, s0, s1
    str  s0, [x9]
    fcvt d8, s0
    SELX1 Ls_setDoubleValue
    GET  x0, _g_level
    fmov d0, d8
    bl   _objc_msgSend

    mov  x19, #-1                         // a message coming in?
    mov  x20, #0
2:  mov  x0, x20
    bl   _rx_progress
    tbz  x0, #63, 3f
    add  x20, x20, #1
    cmp  x20, #5
    b.lo 2b
    b    4f
3:  mov  x19, x0
4:  GET  x9, _g_listening
    cbnz x9, 5f
    mov  x19, #-1
5:  GET  x9, _g_lastprog                  // menu-bar title: " 40%" while hearing
    cmp  x9, x19
    b.eq 7f
    PUT  x19, _g_lastprog
    ADRL x0, Ls_key_none
    tbnz x19, #63, 6f
    str  x19, [sp]
    ADRL x0, _g_buf
    mov  x1, #512
    ADRL x2, Ls_badge
    bl   _snprintf
    ADRL x0, _g_buf
    bl   _strlen
    ADRL x9, _g_buf                       // append "%"
    mov  w10, #37
    strb w10, [x9, x0]
    add  x0, x0, #1
    strb wzr, [x9, x0]
    ADRL x0, _g_buf
6:  bl   _nsstr
    mov  x2, x0
    GET  x0, _g_sbutton
    MSG1 Ls_setTitle

7:  GET  x9, _g_hold                      // the status line
    cbz  x9, 8f
    sub  x9, x9, #1
    PUT  x9, _g_hold
    b    9f
8:  ADRL x0, _tx_active
    ldr  x0, [x0]
    cbz  x0, 10f
    ADRL x0, Ls_st_play
    b    12f
10: GET  x9, _g_listening
    cbnz x9, 11f
    ADRL x0, Ls_st_off
    b    12f
11: ADRL x0, Ls_st_listen
    tbnz x19, #63, 12f
    ADRL x10, Lmode_names
    ldr  x9, [x10, x20, lsl #3]
    str  x9, [sp]
    str  x19, [sp, #8]
    ADRL x0, _g_buf
    mov  x1, #512
    ADRL x2, Ls_st_hear
    bl   _snprintf
    ADRL x0, _g_buf
12: bl   _nsstr
    mov  x2, x0
    GET  x0, _g_status
    MSG1 Ls_setStringValue
9:  ldp  d8, d9, [sp, #96]
    LEAVE 32

// copyLast:
_m_copy:
    ENTER 0
    GET  x19, _g_last
    cbz  x19, 1f
    CLS  Ls_NSPasteboard
    MSG0 Ls_generalPB
    mov  x20, x0
    MSG0 Ls_clearContents
    LDGOT x8, _NSPasteboardTypeString
    ldr  x3, [x8]
    mov  x0, x20
    mov  x2, x19
    MSG2 Ls_setStrForType
    LEAVE 0
1:  bl   _NSBeep
    LEAVE 0

// clearLog:
_m_clear:
    ENTER 0
    ADRL x0, Ls_key_none
    bl   _nsstr
    mov  x2, x0
    GET  x0, _g_log
    MSG1 Ls_setString
    PUT  xzr, _g_n_heard
    PUT  xzr, _g_n_fixed
    PUT  xzr, _g_n_lost
    bl   _update_counts
    LEAVE 0

// showWindow:
_m_show:
    ENTER 0
    GET  x0, _g_win
    mov  x2, #0
    MSG1 Ls_makeKey
    GET  x0, _g_app
    mov  x2, #1
    MSG1 Ls_activate
    LEAVE 0

// sendClip: — the clipboard, in the mode the item's tag names
_m_clip:
    ENTER 0
    mov  x19, x2
    ADRL x9, _tx_active
    ldr  x9, [x9]
    cbz  x9, 1f
    ADRL x0, Ls_st_busy
    bl   _notice
    bl   _NSBeep
    LEAVE 0
1:  CLS  Ls_NSPasteboard
    MSG0 Ls_generalPB
    LDGOT x8, _NSPasteboardTypeString
    ldr  x2, [x8]
    MSG1 Ls_stringForType
    cbnz x0, 2f
    ADRL x0, Ls_st_noclip
    bl   _notice
    bl   _NSBeep
    LEAVE 0
2:  mov  x20, x0
    mov  x0, x19
    MSG0 Ls_tag
    cmp  x0, #4
    csel x21, x0, xzr, ls
    GET  x0, _g_seg
    mov  x2, x21
    MSG1 Ls_setSelSeg
    bl   _m_mode
    GET  x0, _g_field
    mov  x2, x20
    MSG1 Ls_setStringValue
    bl   _update_est
    bl   _m_send
    LEAVE 0

// applicationShouldHandleReopen:hasVisibleWindows: — clicking the Dock icon opens the window
_m_reopen:
    ENTER 0
    bl   _m_show
    mov  x0, #1
    LEAVE 0

// applicationShouldTerminateAfterLastWindowClosed: — no, it lives in the menu bar too
_m_no:
    mov  x0, #0
    ret

// applicationDockMenu:
_m_dock:
    ADRL x9, _g_dock
    ldr  x0, [x9]
    ret

// saveRecording: — the last 30 s the microphone heard, as a WAV
//   into ~/Developer/asmtone/recordings when that folder can be made, else the Desktop
_m_recsave:
    ENTER 32
    bl   _NSHomeDirectory
    MSG0 Ls_UTF8String
    mov  x19, x0
    str  x19, [sp]
    ADRL x0, _g_dir
    mov  x1, #512
    ADRL x2, Ls_rec_dir1
    bl   _snprintf
    ADRL x0, _g_dir
    mov  w1, #0x1ED                       // 0755
    bl   _mkdir
    ADRL x0, _g_dir
    mov  w1, #2                           // W_OK
    bl   _access
    cbz  w0, 1f
    str  x19, [sp]
    ADRL x0, _g_dir
    mov  x1, #512
    ADRL x2, Ls_rec_dir2
    bl   _snprintf
1:  add  x0, sp, #96
    bl   _time
    add  x0, sp, #96
    ADRL x1, _g_tm
    bl   _localtime_r
    ADRL x0, _g_tbuf
    mov  x1, #64
    ADRL x2, Ls_rec_time
    ADRL x3, _g_tm
    bl   _strftime
    ADRL x9, _g_dir
    str  x9, [sp]
    ADRL x9, _g_tbuf
    str  x9, [sp, #8]
    ADRL x0, _g_path
    mov  x1, #768
    ADRL x2, Ls_rec_path
    bl   _snprintf
    ADRL x0, _g_path
    bl   _rec_save
    cbnz x0, 2f
    ADRL x9, _g_path
    str  x9, [sp]
    ADRL x0, _g_buf
    mov  x1, #512
    ADRL x2, Ls_rec_ok
    bl   _snprintf
    ADRL x0, _g_buf
    bl   _notice
    LEAVE 32
2:  ADRL x0, Ls_rec_fail
    bl   _notice
    bl   _NSBeep
    LEAVE 32

// const char *_failed_path(void) — ~/Library/Application Support/asmtone/last-failed-message.wav
_failed_path:
    ENTER 16
    bl   _NSHomeDirectory
    MSG0 Ls_UTF8String
    str  x0, [sp]
    ADRL x0, _g_dir
    mov  x1, #512
    ADRL x2, Ls_fail_dir
    bl   _snprintf
    ADRL x0, _g_dir
    mov  w1, #0x1ED
    bl   _mkdir
    ADRL x9, _g_dir
    str  x9, [sp]
    ADRL x0, _g_fpath
    mov  x1, #768
    ADRL x2, Ls_fail_path
    bl   _snprintf
    ADRL x0, _g_fpath
    LEAVE 16

// _save_failed(void) — the last minute of sound, which holds the message that failed
_save_failed:
    ENTER 0
    bl   _failed_path
    bl   _rec_save
    LEAVE 0

// showFailed: — reveal last-failed-message.wav in Finder (to send it to whoever's helping)
_m_showfailed:
    ENTER 16
    bl   _failed_path
    mov  x19, x0
    mov  w1, #0                           // F_OK
    bl   _access
    cbz  w0, 1f
    ADRL x0, Ls_fail_none
    bl   _notice
    bl   _NSBeep
    LEAVE 16
1:  mov  x0, x19
    bl   _nsstr
    mov  x20, x0
    CLS  Ls_NSURL
    mov  x2, x20
    MSG1 Ls_fileURL
    str  x0, [sp, #96]
    CLS  Ls_NSArray
    add  x2, sp, #96
    mov  x3, #1
    MSG2 Ls_arrayObjs
    mov  x20, x0
    CLS  Ls_NSWorkspace
    MSG0 Ls_sharedWS
    mov  x2, x20
    MSG1 Ls_activateFV
    LEAVE 16
