
// xd_test.mm
// Full-screen tweak UI — "xd test"
// Drops a UIWindow overlay that covers the screen and can be hidden with the Hide button.
// Connect button attempts to call ACCompanion.connect (safe if absent).
//
// Compile / inject as you normally do for tweaks. This file is intended as a self-contained
// UI overlay implementation in Objective-C++ for mobile tweak injection.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static UIWindow *xd_window = nil;
static UIViewController *xd_vc = nil;


// ===== Spawn / RPC integration (merged from your old tweak) =====
// Source: user's old.txt decompilation snippets (see file citation). 
// This adds helper functions to spawn items by name or index and attempts to call
// common RPC/il2cpp entry points if present.
#import <dlfcn.h>

static void (*RPC_SpawnPickup_Internal_ptr)(const char *itemID, float x, float y, float z, int count) = NULL;
static void (*RPC_SpawnPickup_vec3_ptr)(const char *itemID, struct { float x,y,z; } pos, int count) = NULL;

// Attempt to resolve common symbols (best-effort — host binary must export these)
static void resolve_spawn_symbols(void) {
    if (RPC_SpawnPickup_Internal_ptr) return;
    void *handle = dlopen(NULL, RTLD_NOW);
    if (!handle) return;
    RPC_SpawnPickup_Internal_ptr = (void(*)(const char*,float,float,float,int))dlsym(handle, "RPC_SpawnPickup_Internal");
    if (!RPC_SpawnPickup_Internal_ptr) {
        RPC_SpawnPickup_Internal_ptr = (void(*)(const char*,float,float,float,int))dlsym(handle, "_RPC_SpawnPickup_Internal");
    }
    // try other possible names (IL2CPP exported wrappers)
    if (!RPC_SpawnPickup_Internal_ptr) {
        RPC_SpawnPickup_vec3_ptr = (void(*)(const char*, struct { float x,y,z; }, int))dlsym(handle, "RPC_SpawnPickup");
    }
    dlclose(handle);
}

// Spawn by item name (C string). Returns YES if call was attempted.
static BOOL SpawnItemByName(const char *itemName, float px, float py, float pz, int count) {
    resolve_spawn_symbols();
    if (RPC_SpawnPickup_Internal_ptr) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        RPC_SpawnPickup_Internal_ptr(itemName, px, py, pz, count);
#pragma clang diagnostic pop
        return YES;
    }
    if (RPC_SpawnPickup_vec3_ptr) {
        struct { float x,y,z; } pos = {px,py,pz};
        RPC_SpawnPickup_vec3_ptr(itemName, pos, count);
        return YES;
    }
    // As a fallback, try calling an IL2CPP RPC via Objective-C bridging if present:
    Class gameManager = NSClassFromString(@"GameManager");
    SEL spawnSel = NSSelectorFromString(@"spawnPickupWithID:position:count:");
    if (gameManager && [gameManager respondsToSelector:spawnSel]) {
        NSInvocation *inv = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [gameManager performSelector:spawnSel withObject:[NSString stringWithUTF8String:itemName]];
#pragma clang diagnostic pop
        return YES;
    }
    return NO;
}

// Helper: spawn at player's position if available.
static void SpawnAtPlayer(const char *itemName, int count) {
    // try to find local player and its transform
    Class PlayerClass = NSClassFromString(@"LocalPlayer");
    if (PlayerClass) {
        id shared = nil;
        SEL sharedSel = NSSelectorFromString(@"sharedInstance");
        if ([PlayerClass respondsToSelector:sharedSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            shared = [PlayerClass performSelector:sharedSel];
#pragma clang diagnostic pop
        }
        if (shared) {
            SEL posSel = NSSelectorFromString(@"position");
            if ([shared respondsToSelector:posSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                id pos = [shared performSelector:posSel];
#pragma clang diagnostic pop
                if (pos && [pos respondsToSelector:NSSelectorFromString(@"x")]) {
                    float x = ((float (*)(id,SEL))objc_msgSend)((id)pos, NSSelectorFromString(@"x"));
                    float y = ((float (*)(id,SEL))objc_msgSend)((id)pos, NSSelectorFromString(@"y"));
                    float z = ((float (*)(id,SEL))objc_msgSend)((id)pos, NSSelectorFromString(@"z"));
                    if (SpawnItemByName(itemName, x,y,z, count)) return;
                }
            }
        }
    }
    // last resort: spawn at origin
    SpawnItemByName(itemName, 0.0f, 1.0f, 0.0f, count);
}

// Example bridge function exposed for external calls
extern "C" void XD_SpawnItem(const char *itemName, int count) {
    SpawnAtPlayer(itemName, count);
}

// End spawn integration

static UIWindow *XDKeyWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene*)scene;
                for (UIWindow *w in ws.windows) {
                    if (w.isKeyWindow) return w;
                }
                if (ws.windows.count) return ws.windows.firstObject;
            }
        }
    }
    return [UIApplication sharedApplication].keyWindow;
}

static void makeRound(UIView *v, CGFloat r) {
    v.layer.cornerRadius = r;
    v.layer.masksToBounds = YES;
}

static void XDShowToast(UIView *parent, NSString *text) {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectZero];
    lbl.text = text;
    lbl.textColor = [UIColor whiteColor];
    lbl.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    lbl.textAlignment = NSTextAlignmentCenter;
    lbl.numberOfLines = 2;
    lbl.alpha = 0.0;
    lbl.layer.cornerRadius = 8;
    lbl.layer.masksToBounds = YES;
    CGSize s = [lbl sizeThatFits:CGSizeMake(parent.bounds.size.width*0.8, CGFLOAT_MAX)];
    CGFloat w = MIN(s.width + 24, parent.bounds.size.width*0.9);
    CGFloat h = s.height + 18;
    lbl.frame = CGRectMake((parent.bounds.size.width-w)/2, parent.bounds.size.height - h - 80, w, h);
    [parent addSubview:lbl];
    [UIView animateWithDuration:0.25 animations:^{
        lbl.alpha = 1.0;
    } completion:^(BOOL finished){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.3 animations:^{
                lbl.alpha = 0.0;
            } completion:^(BOOL fin){
                [lbl removeFromSuperview];
            }];
        });
    }];
}

static void tryConnect(UIView *parent) {
    // Show attempting toast
    XDShowToast(parent, @"Connecting...");
    // Attempt to call +[ACCompanion connect] or -connect on a singleton.
    Class cls = NSClassFromString(@"ACCompanion");
    if (cls) {
        SEL sel = NSSelectorFromString(@"connect");
        if ([cls respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [cls performSelector:sel];
#pragma clang diagnostic pop
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                XDShowToast(parent, @"Connected");
            });
            return;
        }
        id shared = nil;
        SEL sharedSel = NSSelectorFromString(@"sharedInstance");
        if ([cls respondsToSelector:sharedSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            shared = [cls performSelector:sharedSel];
#pragma clang diagnostic pop
        }
        if (shared) {
            SEL s2 = NSSelectorFromString(@"connect");
            if ([shared respondsToSelector:s2]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [shared performSelector:s2];
#pragma clang diagnostic pop
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    XDShowToast(parent, @"Connected");
                });
                return;
            }
        }
    }
    // If we fall through, no companion present — show failure
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XDShowToast(parent, @"No companion found");
    });
}

extern "C" void XDShowMenu(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (xd_window) { // already shown, bring to front
            xd_window.hidden = NO;
            [xd_window makeKeyAndVisible];
            return;
        }
        CGRect bounds = XDKeyWindow().bounds;
        xd_window = [[UIWindow alloc] initWithFrame:bounds];
        xd_window.windowLevel = UIWindowLevelAlert + 1000;
        xd_window.backgroundColor = [UIColor clearColor];
        // root vc
        xd_vc = [UIViewController new];
        xd_vc.view.frame = xd_window.bounds;
        // dim background
        UIView *bg = [[UIView alloc] initWithFrame:xd_vc.view.bounds];
        bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        CAGradientLayer *gl = [CAGradientLayer layer];
        gl.frame = bg.bounds;
        gl.colors = @[(id)[UIColor colorWithRed:0.03 green:0.03 blue:0.07 alpha:0.98].CGColor,
                      (id)[UIColor colorWithRed:0.06 green:0.04 blue:0.12 alpha:0.98].CGColor];
        gl.startPoint = CGPointMake(0,0);
        gl.endPoint = CGPointMake(1,1);
        [bg.layer insertSublayer:gl atIndex:0];
        [xd_vc.view addSubview:bg];

        // container that holds the menu content
        UIView *container = [[UIView alloc] initWithFrame:CGRectInset(xd_vc.view.bounds, 20, 40)];
        container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        container.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.25];
        container.layer.cornerRadius = 18;
        container.layer.borderWidth = 1.0;
        container.layer.borderColor = [[UIColor colorWithWhite:1.0 alpha:0.06] CGColor];
        container.clipsToBounds = YES;
        [xd_vc.view addSubview:container];

        // header
        CGFloat headerH = 62;
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, container.bounds.size.width, headerH)];
        header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        header.backgroundColor = [[UIColor colorWithWhite:1.0 alpha:0.02] colorWithAlphaComponent:0.02];
        [container addSubview:header];

        // title label
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 12, container.bounds.size.width-160, headerH-24)];
        title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        title.text = @"xd test"; // user-requested name
        title.textColor = [UIColor colorWithWhite:0.95 alpha:1.0];
        title.font = [UIFont boldSystemFontOfSize:20];
        [header addSubview:title];

        // Connect button (companion-style)
        UIButton *connect = [UIButton buttonWithType:UIButtonTypeSystem];
        connect.frame = CGRectMake(container.bounds.size.width-120, 10, 88, headerH-20);
        connect.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        connect.layer.cornerRadius = 10;
        connect.layer.masksToBounds = YES;
        connect.backgroundColor = [UIColor colorWithRed:0.12 green:0.46 blue:0.98 alpha:1.0];
        [connect setTitle:@"Connect" forState:UIControlStateNormal];
        [connect setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        connect.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        [connect addTarget:nil action:@selector(xd_connectTapped:) forControlEvents:UIControlEventTouchUpInside];
        [header addSubview:connect];

        // Hide button (close)
        UIButton *hide = [UIButton buttonWithType:UIButtonTypeSystem];
        hide.frame = CGRectMake(container.bounds.size.width-54, 12, 40, 40);
        hide.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        hide.layer.cornerRadius = 20;
        hide.layer.masksToBounds = YES;
        hide.backgroundColor = [[UIColor colorWithWhite:0.0 alpha:0.2] colorWithAlphaComponent:0.2];
        [hide setTitle:@"✕" forState:UIControlStateNormal];
        [hide setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        hide.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
        [hide addTarget:nil action:@selector(xd_hideTapped:) forControlEvents:UIControlEventTouchUpInside];
        [header addSubview:hide];

        // content area (simple scrollable list)
        UIScrollView *content = [[UIScrollView alloc] initWithFrame:CGRectMake(0, headerH, container.bounds.size.width, container.bounds.size.height - headerH)];
        content.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        content.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.02];
        [container addSubview:content];

        // Example items (these can be replaced with the real menu items)
        CGFloat y = 12;
        for (int i=0;i<12;i++) {
            UIView *row = [[UIView alloc] initWithFrame:CGRectMake(12, y, content.bounds.size.width-24, 48)];
            row.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            row.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.03];
            row.layer.cornerRadius = 10;
            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectInset(row.bounds, 12, 8)];
            lbl.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
            lbl.text = [NSString stringWithFormat:@"Option %d", i+1];
            lbl.textColor = [UIColor colorWithWhite:0.92 alpha:1.0];
            [row addSubview:lbl];
            [content addSubview:row];
            y += 56;
        }
        content.contentSize = CGSizeMake(content.bounds.size.width, y);

        // simple tap to background to dismiss (outside container)
        UIView *tapCatcher = [[UIView alloc] initWithFrame:xd_vc.view.bounds];
        tapCatcher.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        tapCatcher.backgroundColor = [UIColor clearColor];
        [xd_vc.view insertSubview:tapCatcher belowSubview:container];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:nil action:@selector(xd_backgroundTapped:)];
        [tapCatcher addGestureRecognizer:tap];

        xd_window.rootViewController = xd_vc;
        xd_window.hidden = NO;
        [xd_window makeKeyAndVisible];

        // Retain container in associated object so selectors can find it
        objc_setAssociatedObject(xd_window, "xd_container", container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
}

// action implementations
__attribute__((visibility("default"))) void xd_connectTapped(id sender) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *container = objc_getAssociatedObject(xd_window, "xd_container");
        if (container) {
            tryConnect(container);
        } else {
            UIView *v = xd_vc.view ?: XDKeyWindow();
            XDShowToast(v, @"Connecting...");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                XDShowToast(v, @"No companion found");
            });
        }
    });
}

__attribute__((visibility("default"))) void xd_hideTapped(id sender) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!xd_window) return;
        xd_window.hidden = YES;
        // Do not destroy window so it can be re-shown quickly
    });
}

__attribute__((visibility("default"))) void xd_backgroundTapped(id sender) {
    // Hide when tapping outside
    xd_hideTapped(nil);
}

// optional: fully remove and cleanup
extern "C" void XDCloseAndCleanup(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!xd_window) return;
        xd_window.hidden = YES;
        objc_setAssociatedObject(xd_window, "xd_container", nil, OBJC_ASSOCIATION_ASSIGN);
        xd_window.rootViewController = nil;
        xd_window = nil;
        xd_vc = nil;
    });
}

// For convenience, automatically show on load (comment out if not desired)
__attribute__((constructor)) static void auto_show_xd_ui(void) {
    // small delay to allow host app to finish launching
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        XDShowMenu();
    });
}

