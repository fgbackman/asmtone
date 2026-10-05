// util.s — Objective-C messaging shortcuts and small AppKit helpers for asmtone.

.include "macros.inc"

.section __TEXT,__cstring
Ls_NSString:        .asciz "NSString"
Ls_alloc:           .asciz "alloc"
Ls_autorelease:     .asciz "autorelease"
Ls_strUTF8:         .asciz "stringWithUTF8String:"
Ls_initBytes:       .asciz "initWithBytes:length:encoding:"
Ls_NSTextField:     .asciz "NSTextField"
Ls_labelWith:       .asciz "labelWithString:"
Ls_NSButton:        .asciz "NSButton"
Ls_buttonWith:      .asciz "buttonWithTitle:target:action:"
Ls_setFrame:        .asciz "setFrame:"
Ls_addSubview:      .asciz "addSubview:"
Ls_setMask:         .asciz "setAutoresizingMask:"
Ls_NSImage:         .asciz "NSImage"
Ls_imageSym:        .asciz "imageWithSystemSymbolName:accessibilityDescription:"
Ls_NSMenuItem:      .asciz "NSMenuItem"
Ls_initMenuItem:    .asciz "initWithTitle:action:keyEquivalent:"
Ls_setTarget:       .asciz "setTarget:"
Ls_setTag:          .asciz "setTag:"
Ls_addItem:         .asciz "addItem:"
Ls_empty:           .asciz ""

.text
.p2align 2

// id _msg0..4(id rcv, const char *selname, a, b, c, d) — integer/pointer arguments only
.globl _msg0
_msg0:
    ENTER 0
    mov  x19, x0
    mov  x0, x1
    bl   _sel_registerName
    mov  x1, x0
    mov  x0, x19
    bl   _objc_msgSend
    LEAVE 0

.globl _msg1
_msg1:
    ENTER 0
    mov  x19, x0
    mov  x20, x2
    mov  x0, x1
    bl   _sel_registerName
    mov  x1, x0
    mov  x0, x19
    mov  x2, x20
    bl   _objc_msgSend
    LEAVE 0

.globl _msg2
_msg2:
    ENTER 0
    mov  x19, x0
    mov  x20, x2
    mov  x21, x3
    mov  x0, x1
    bl   _sel_registerName
    mov  x1, x0
    mov  x0, x19
    mov  x2, x20
    mov  x3, x21
    bl   _objc_msgSend
    LEAVE 0

.globl _msg3
_msg3:
    ENTER 0
    mov  x19, x0
    mov  x20, x2
    mov  x21, x3
    mov  x22, x4
    mov  x0, x1
    bl   _sel_registerName
    mov  x1, x0
    mov  x0, x19
    mov  x2, x20
    mov  x3, x21
    mov  x4, x22
    bl   _objc_msgSend
    LEAVE 0

.globl _msg4
_msg4:
    ENTER 0
    mov  x19, x0
    mov  x20, x2
    mov  x21, x3
    mov  x22, x4
    mov  x23, x5
    mov  x0, x1
    bl   _sel_registerName
    mov  x1, x0
    mov  x0, x19
    mov  x2, x20
    mov  x3, x21
    mov  x4, x22
    mov  x5, x23
    bl   _objc_msgSend
    LEAVE 0

// id _nsstr(const char *utf8) — autoreleased NSString; invalid UTF-8 falls back to Latin-1
.globl _nsstr
_nsstr:
    ENTER 0
    mov  x19, x0
    CLS  Ls_NSString
    mov  x2, x19
    MSG1 Ls_strUTF8
    cbnz x0, 1f
    mov  x0, x19
    bl   _strlen
    mov  x1, x0
    mov  x0, x19
    mov  x2, #5
    bl   _nsstr_bytes
1:  LEAVE 0

// id _nsstr_bytes(const void *bytes, long len, long encoding) — autoreleased, or nil
.globl _nsstr_bytes
_nsstr_bytes:
    ENTER 0
    mov  x19, x0
    mov  x20, x1
    mov  x21, x2
    CLS  Ls_NSString
    MSG0 Ls_alloc
    mov  x2, x19
    mov  x3, x20
    mov  x4, x21
    MSG3 Ls_initBytes
    cbz  x0, 1f
    MSG0 Ls_autorelease
1:  LEAVE 0

// void _place(id view, id parent, long mask, NSRect frame in d0-d3)
.globl _place
_place:
    ENTER 32
    stp  d0, d1, [sp, #96]
    stp  d2, d3, [sp, #112]
    mov  x19, x0
    mov  x20, x1
    mov  x21, x2
    SELX1 Ls_setFrame
    mov  x0, x19
    ldp  d0, d1, [sp, #96]
    ldp  d2, d3, [sp, #112]
    bl   _objc_msgSend
    mov  x0, x19
    mov  x2, x21
    MSG1 Ls_setMask
    mov  x0, x20
    mov  x2, x19
    MSG1 Ls_addSubview
    mov  x0, x19
    LEAVE 32

// id _label(const char *text, id parent, long mask, NSRect in d0-d3)
.globl _label
_label:
    ENTER 32
    stp  d0, d1, [sp, #96]
    stp  d2, d3, [sp, #112]
    mov  x20, x1
    mov  x21, x2
    bl   _nsstr
    mov  x19, x0
    CLS  Ls_NSTextField
    mov  x2, x19
    MSG1 Ls_labelWith
    mov  x1, x20
    mov  x2, x21
    ldp  d0, d1, [sp, #96]
    ldp  d2, d3, [sp, #112]
    bl   _place
    LEAVE 32

// id _button(const char *title, const char *action, id target, id parent, long mask, NSRect)
.globl _button
_button:
    ENTER 32
    stp  d0, d1, [sp, #96]
    stp  d2, d3, [sp, #112]
    mov  x19, x1
    mov  x20, x2
    mov  x21, x3
    mov  x22, x4
    bl   _nsstr
    mov  x23, x0
    mov  x0, x19
    bl   _sel_registerName
    mov  x19, x0
    CLS  Ls_NSButton
    mov  x2, x23
    mov  x3, x20
    mov  x4, x19
    MSG3 Ls_buttonWith
    mov  x1, x21
    mov  x2, x22
    ldp  d0, d1, [sp, #96]
    ldp  d2, d3, [sp, #112]
    bl   _place
    LEAVE 32

// id _symbol(const char *name) — an SF Symbol image, or nil
.globl _symbol
_symbol:
    ENTER 0
    bl   _nsstr
    mov  x19, x0
    CLS  Ls_NSImage
    mov  x2, x19
    mov  x3, #0
    MSG2 Ls_imageSym
    LEAVE 0

// id _menu_item(id menu, const char *title, const char *action, const char *key, id target, long tag)
//   added to menu; returns the item
.globl _menu_item
_menu_item:
    ENTER 16
    mov  x19, x0
    mov  x20, x1
    mov  x21, x2
    mov  x22, x3
    mov  x23, x4
    str  x5, [sp, #96]
    mov  x0, x20
    bl   _nsstr
    mov  x20, x0
    mov  x0, x22
    bl   _nsstr
    mov  x22, x0
    mov  x0, #0
    cbz  x21, 1f
    mov  x0, x21
    bl   _sel_registerName
1:  mov  x21, x0
    CLS  Ls_NSMenuItem
    MSG0 Ls_alloc
    mov  x2, x20
    mov  x3, x21
    mov  x4, x22
    MSG3 Ls_initMenuItem
    mov  x20, x0
    MSG0 Ls_autorelease
    cbz  x23, 2f
    mov  x0, x20
    mov  x2, x23
    MSG1 Ls_setTarget
2:  mov  x0, x20
    ldr  x2, [sp, #96]
    MSG1 Ls_setTag
    mov  x0, x19
    mov  x2, x20
    MSG1 Ls_addItem
    mov  x0, x20
    LEAVE 16
