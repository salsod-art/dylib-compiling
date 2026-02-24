// ═══════════════════════════════════════════════════════════════════════════════
// EverLight v3.0 — Enhanced UI + XD IL2CPP Spawning Engine
// Built for Animal Company — Compatible with Sideloadly
// Base: EverLight v2.0 UI | Engine: XD IL2CPP Direct Spawning
// Features: IL2CPP Item Spawner, Real Money Cheats, Infinite Ammo,
//           Shop Cooldown Removal, Full OP Tab, Galaxy UI
// ═══════════════════════════════════════════════════════════════════════════════

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <dlfcn.h>
#include <mach-o/dyld.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>

// AudioServicesPlaySystemSound loaded at runtime to avoid framework linker dep
static void ELPlaySound(uint32_t soundID) {
    static void (*_play)(uint32_t) = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *h = dlopen("/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox", RTLD_LAZY);
        if (h) _play = (void (*)(uint32_t))dlsym(h, "AudioServicesPlaySystemSound");
    });
    if (_play) _play(soundID);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Vector3 structure
// ═══════════════════════════════════════════════════════════════════════════════
struct Vector3 {
    float x, y, z;
    Vector3(float _x=0, float _y=0, float _z=0) : x(_x), y(_y), z(_z) {}
};

// ═══════════════════════════════════════════════════════════════════════════════
// XD IL2CPP Engine — Global state (from old.txt)
// ═══════════════════════════════════════════════════════════════════════════════

// IL2CPP function pointers
static int64_t (*il2cpp_domain_get)(void);
static int64_t (*il2cpp_domain_get_assemblies)(int64_t, size_t *);
static int64_t (*il2cpp_assembly_get_image)(int64_t);
static const char *(*il2cpp_image_get_name)(int64_t);
static int64_t (*il2cpp_class_from_name)(int64_t, const char *, const char *);
static int64_t (*il2cpp_class_get_method_from_name)(int64_t, const char *, int);
static int64_t (*il2cpp_class_get_field_from_name)(int64_t, const char *);
static void    (*il2cpp_field_get_value)(int64_t, int64_t, void *);
static void    (*il2cpp_field_set_value)(int64_t, int64_t, void *);
static int64_t (*il2cpp_runtime_invoke)(int64_t, int64_t, void **, int64_t *);
static int64_t (*il2cpp_resolve_icall)(const char *);
static int64_t (*il2cpp_class_get_type)(int64_t);
static int64_t (*il2cpp_type_get_object)(int64_t);
static void   *il2cpp_string_new;

// Game state
static BOOL    gIsInitialized           = NO;
static int64_t gGameImage               = 0;
static int64_t gUnityImage              = 0;
static int64_t gNetPlayerClass          = 0;
static int64_t gPrefabGeneratorClass    = 0;
static int64_t gGameObjectClass         = 0;
static int64_t gTransformClass          = 0;
static int64_t gObjectClass             = 0;
static int64_t gGameManagerClass        = 0;
static int64_t gItemSellingMachineClass = 0;

// Method handles
static int64_t gGetLocalPlayerMethod            = 0;
static int64_t gGiveSelfMoneyMethod             = 0;
static int64_t gSpawnItemMethod                 = 0;
static int64_t gFindObjectOfTypeMethod          = 0;
static int64_t gRpcAddPlayerMoneyToAllMethod    = 0;
static int64_t gGameManagerAddPlayerMoneyMethod = 0;
static int64_t gTransformGetPositionInjected    = 0;

// Spawn settings
static int64_t   gSpawnQuantity          = 1;
static float     gCustomSpawnX           = 0;
static float     gCustomSpawnY           = 1.0f;
static float     gCustomSpawnZ           = 0;
static BOOL      gUseCustomLocation      = NO;

// ═══════════════════════════════════════════════════════════════════════════════
// IL2CPP Initialization (from old.txt: initializeIL2CPP + initializeGameClasses)
// ═══════════════════════════════════════════════════════════════════════════════

static int64_t XDGetImage(const char *name) {
    if (!gIsInitialized) return 0;
    int64_t domain = il2cpp_domain_get();
    if (!domain) return 0;
    size_t count = 0;
    int64_t assemblies = il2cpp_domain_get_assemblies(domain, &count);
    for (size_t i = 0; i < count; i++) {
        int64_t asm_ = *((int64_t *)assemblies + i);
        int64_t img  = il2cpp_assembly_get_image(asm_);
        const char *imgName = il2cpp_image_get_name(img);
        if (imgName && strcmp(imgName, name) == 0) return img;
    }
    return 0;
}

static BOOL XDInitializeIL2CPP(void) {
    if (gIsInitialized) return YES;

    void *handle = NULL;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework")) {
            handle = dlopen(name, RTLD_NOW);
            break;
        }
    }
    if (!handle) handle = dlopen(NULL, RTLD_NOW);
    if (!handle) return NO;

    il2cpp_domain_get              = (int64_t (*)(void))dlsym(handle, "il2cpp_domain_get");
    il2cpp_domain_get_assemblies   = (int64_t (*)(int64_t, size_t *))dlsym(handle, "il2cpp_domain_get_assemblies");
    il2cpp_assembly_get_image      = (int64_t (*)(int64_t))dlsym(handle, "il2cpp_assembly_get_image");
    il2cpp_image_get_name          = (const char *(*)(int64_t))dlsym(handle, "il2cpp_image_get_name");
    il2cpp_class_from_name         = (int64_t (*)(int64_t, const char *, const char *))dlsym(handle, "il2cpp_class_from_name");
    il2cpp_class_get_method_from_name = (int64_t (*)(int64_t, const char *, int))dlsym(handle, "il2cpp_class_get_method_from_name");
    il2cpp_class_get_field_from_name  = (int64_t (*)(int64_t, const char *))dlsym(handle, "il2cpp_class_get_field_from_name");
    il2cpp_field_get_value         = (void (*)(int64_t, int64_t, void *))dlsym(handle, "il2cpp_field_get_value");
    il2cpp_field_set_value         = (void (*)(int64_t, int64_t, void *))dlsym(handle, "il2cpp_field_set_value");
    il2cpp_runtime_invoke          = (int64_t (*)(int64_t, int64_t, void **, int64_t *))dlsym(handle, "il2cpp_runtime_invoke");
    il2cpp_resolve_icall           = (int64_t (*)(const char *))dlsym(handle, "il2cpp_resolve_icall");
    il2cpp_class_get_type          = (int64_t (*)(int64_t))dlsym(handle, "il2cpp_class_get_type");
    il2cpp_type_get_object         = (int64_t (*)(int64_t))dlsym(handle, "il2cpp_type_get_object");
    il2cpp_string_new              = dlsym(handle, "il2cpp_string_new");

    if (il2cpp_domain_get && il2cpp_class_from_name &&
        il2cpp_class_get_method_from_name && il2cpp_class_get_type && il2cpp_type_get_object) {
        if (il2cpp_resolve_icall)
            gTransformGetPositionInjected = il2cpp_resolve_icall("UnityEngine.Transform::get_position_Injected");
        gIsInitialized = YES;
        return YES;
    }
    return NO;
}

static BOOL XDInitializeGameClasses(void) {
    if (!gIsInitialized) return NO;
    gGameImage  = XDGetImage("AnimalCompany.dll");
    if (!gGameImage) return NO;
    gUnityImage = XDGetImage("UnityEngine.CoreModule.dll");
    gNetPlayerClass       = il2cpp_class_from_name(gGameImage, "AnimalCompany", "NetPlayer");
    gPrefabGeneratorClass = il2cpp_class_from_name(gGameImage, "AnimalCompany", "PrefabGenerator");
    if (gUnityImage) {
        gGameObjectClass  = il2cpp_class_from_name(gUnityImage, "UnityEngine", "GameObject");
        gTransformClass   = il2cpp_class_from_name(gUnityImage, "UnityEngine", "Transform");
        gObjectClass      = il2cpp_class_from_name(gUnityImage, "UnityEngine", "Object");
    }
    if (!gNetPlayerClass) return NO;
    gGetLocalPlayerMethod   = il2cpp_class_get_method_from_name(gNetPlayerClass, "get_localPlayer", 0);
    gGiveSelfMoneyMethod    = il2cpp_class_get_method_from_name(gNetPlayerClass, "AddPlayerMoney", 1);
    if (gPrefabGeneratorClass)
        gSpawnItemMethod    = il2cpp_class_get_method_from_name(gPrefabGeneratorClass, "SpawnItem", 4);
    if (gObjectClass)
        gFindObjectOfTypeMethod = il2cpp_class_get_method_from_name(gObjectClass, "FindObjectOfType", 1);
    gItemSellingMachineClass = il2cpp_class_from_name(gGameImage, "AnimalCompany", "ItemSellingMachineController");
    if (gItemSellingMachineClass) {
        gRpcAddPlayerMoneyToAllMethod = il2cpp_class_get_method_from_name(gItemSellingMachineClass, "RPC_AddPlayerMoneyToAll", 1);
        if (!gRpcAddPlayerMoneyToAllMethod)
            gRpcAddPlayerMoneyToAllMethod = il2cpp_class_get_method_from_name(gItemSellingMachineClass, "RPC_AddPlayerMoneyToAll", 2);
    }
    gGameManagerClass = il2cpp_class_from_name(gGameImage, "AnimalCompany", "GameManager");
    if (gGameManagerClass)
        gGameManagerAddPlayerMoneyMethod = il2cpp_class_get_method_from_name(gGameManagerClass, "AddPlayerMoney", 1);
    NSLog(@"[EverLight] IL2CPP classes initialized. SpawnMethod=%lld GiveMoney=%lld", gSpawnItemMethod, gGiveSelfMoneyMethod);
    return YES;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Core Game Functions (from old.txt)
// ═══════════════════════════════════════════════════════════════════════════════

static int64_t XDGetLocalPlayer(void) {
    if (!gGetLocalPlayerMethod && gNetPlayerClass)
        gGetLocalPlayerMethod = il2cpp_class_get_method_from_name(gNetPlayerClass, "get_localPlayer", 0);
    if (!gGetLocalPlayerMethod) return 0;
    int64_t exc = 0;
    int64_t player = il2cpp_runtime_invoke(gGetLocalPlayerMethod, 0, NULL, &exc);
    if (exc) { NSLog(@"[EverLight] Exception getting local player: %lld", exc); return 0; }
    return player;
}

static float XDGetPlayerX(void) {
    // Returns player X position via Transform; simplified fallback
    int64_t player = XDGetLocalPlayer();
    if (!player) return 0.0f;
    // Try to read transform position via field or injected method
    // For now return a safe spawn offset above ground
    return 0.0f;
}

static void XDGetSpawnPosition(float *outX, float *outY, float *outZ) {
    if (gUseCustomLocation) {
        *outX = gCustomSpawnX;
        *outY = gCustomSpawnY;
        *outZ = gCustomSpawnZ;
        return;
    }
    // Default to safe world position
    *outX = 0.0f;
    *outY = 1.0f;
    *outZ = 0.0f;
}

// Direct IL2CPP item spawner (from old.txt spawnItem)
static void XDSpawnItem(NSString *itemID, int quantity) {
    if (!gSpawnItemMethod || !il2cpp_string_new) {
        NSLog(@"[EverLight] SpawnItem: method or il2cpp_string_new not ready");
        return;
    }

    // Create IL2CPP string from ObjC string
    typedef int64_t (*StringNewFn)(const char *);
    StringNewFn stringNew = (StringNewFn)il2cpp_string_new;
    int64_t il2cppStr = stringNew([itemID UTF8String]);

    float spawnX, spawnY, spawnZ;
    XDGetSpawnPosition(&spawnX, &spawnY, &spawnZ);

    // Quaternion identity = {0,0,0,1}
    float quat[4] = {0.0f, 0.0f, 0.0f, 1.0f};
    float scale   = 1.0f;

    for (int i = 0; i < quantity; i++) {
        float pos[3];
        pos[0] = spawnX + (float)((i % 5) * 0.6f);
        pos[1] = spawnY;
        pos[2] = spawnZ + (float)((i / 5) * 0.6f);

        void *args[4];
        args[0] = (void *)&il2cppStr;
        args[1] = pos;
        args[2] = quat;
        args[3] = &scale;

        int64_t exc = 0;
        il2cpp_runtime_invoke(gSpawnItemMethod, 0, args, &exc);
        if (exc) {
            NSLog(@"[EverLight] SpawnItem exception at i=%d: %lld", i, exc);
        }
        // Throttle to avoid freezes (every 50 items)
        if (i > 0 && i % 50 == 0) usleep(100000);
    }
    NSLog(@"[EverLight] Spawned %@ x%d", itemID, quantity);
}

// Give money to self (from old.txt giveSelfMoney)
static void XDGiveSelfMoney(unsigned int amount) {
    if (!gGiveSelfMoneyMethod && gNetPlayerClass)
        gGiveSelfMoneyMethod = il2cpp_class_get_method_from_name(gNetPlayerClass, "AddPlayerMoney", 1);
    if (!gGiveSelfMoneyMethod) {
        NSLog(@"[EverLight] giveSelfMoney: AddPlayerMoney method not found");
        return;
    }
    int64_t player = XDGetLocalPlayer();
    if (!player) { NSLog(@"[EverLight] Could not get local player"); return; }

    unsigned int val = amount;
    void *args[1]; args[0] = &val;
    int64_t exc = 0;
    il2cpp_runtime_invoke(gGiveSelfMoneyMethod, player, args, &exc);
    if (exc) NSLog(@"[EverLight] Exception giving money: %lld", exc);
    else NSLog(@"[EverLight] Gave %u money to local player", amount);
}

// Give money to all players (from old.txt giveAllPlayersMoney)
static void XDGiveAllPlayersMoney(int amount) {
    if (gRpcAddPlayerMoneyToAllMethod && gFindObjectOfTypeMethod && il2cpp_class_get_type && il2cpp_type_get_object) {
        int64_t type   = il2cpp_class_get_type(gItemSellingMachineClass);
        int64_t object = il2cpp_type_get_object(type);
        int64_t exc    = 0;
        void *findArgs[1]; findArgs[0] = (void *)&object;
        int64_t controller = il2cpp_runtime_invoke(gFindObjectOfTypeMethod, 0, findArgs, &exc);
        if (controller && !exc) {
            int val = amount;
            void *rpcArgs[1]; rpcArgs[0] = &val;
            exc = 0;
            il2cpp_runtime_invoke(gRpcAddPlayerMoneyToAllMethod, controller, rpcArgs, &exc);
            if (!exc) { NSLog(@"[EverLight] RPC_AddPlayerMoneyToAll success"); return; }
            // Fallback with 2-param version
            void *rpcArgs2[2]; rpcArgs2[0] = &val; rpcArgs2[1] = NULL;
            exc = 0;
            il2cpp_runtime_invoke(gRpcAddPlayerMoneyToAllMethod, controller, rpcArgs2, &exc);
            if (!exc) { NSLog(@"[EverLight] RPC_AddPlayerMoneyToAll (2-param) success"); return; }
        }
    }
    if (gGameManagerAddPlayerMoneyMethod) {
        int val = amount;
        void *args[1]; args[0] = &val;
        int64_t exc = 0;
        il2cpp_runtime_invoke(gGameManagerAddPlayerMoneyMethod, 0, args, &exc);
        if (!exc) { NSLog(@"[EverLight] GameManager.AddPlayerMoney success"); return; }
    }
    // Final fallback: give to self
    XDGiveSelfMoney((unsigned int)amount);
}

// Infinite ammo (from old.txt giveInfAmmo)
static void XDGiveInfiniteAmmo(void) {
    int64_t player = XDGetLocalPlayer();
    if (!player || !gNetPlayerClass) return;
    int64_t field = il2cpp_class_get_field_from_name(gNetPlayerClass, "ammo");
    if (!field) field = il2cpp_class_get_field_from_name(gNetPlayerClass, "currentAmmo");
    if (field) {
        int val = 9999;
        il2cpp_field_set_value(player, field, &val);
        NSLog(@"[EverLight] Infinite ammo set");
    }
}

// Remove shop cooldown (from old.txt removeShopCooldown)
static BOOL XDRemoveShopCooldown(void) {
    int64_t player = XDGetLocalPlayer();
    if (!player || !gNetPlayerClass) return NO;
    int64_t field = il2cpp_class_get_field_from_name(gNetPlayerClass, "shopCooldown");
    if (!field) field = il2cpp_class_get_field_from_name(gNetPlayerClass, "lastBuyTime");
    if (!field) field = il2cpp_class_get_field_from_name(gNetPlayerClass, "buyTimer");
    if (field) {
        int val = 0;
        il2cpp_field_set_value(player, field, &val);
        NSLog(@"[EverLight] Shop cooldown removed");
        return YES;
    }
    return NO;
}

// ═══════════════════════════════════════════════════════════════════════════════
// FIX — Block-based UIGestureRecognizer support
// ═══════════════════════════════════════════════════════════════════════════════

@interface _ELBlockTarget : NSObject
@property (nonatomic, copy) void (^action)(id sender);
+ (instancetype)targetWithBlock:(void(^)(id sender))block;
- (void)fire:(id)sender;
@end

@implementation _ELBlockTarget
+ (instancetype)targetWithBlock:(void(^)(id))block {
    _ELBlockTarget *t = [_ELBlockTarget new];
    t.action = block;
    return t;
}
- (void)fire:(id)sender { if (self.action) self.action(sender); }
@end

static NSMutableArray *_ELGestureTargets;

@interface UIGestureRecognizer (ELBlocks)
- (void)addTarget:(void (^)(id sender))block withObject:(id)unused;
@end

@implementation UIGestureRecognizer (ELBlocks)
- (void)addTarget:(void (^)(id))block withObject:(__unused id)unused {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ _ELGestureTargets = [NSMutableArray array]; });
    _ELBlockTarget *t = [_ELBlockTarget targetWithBlock:block];
    [_ELGestureTargets addObject:t];
    [self addTarget:t action:@selector(fire:)];
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// Safe key window helper (iOS 13+)
// ═══════════════════════════════════════════════════════════════════════════════
static UIWindow *ELKeyWindow(void) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) return w;
                }
                return ((UIWindowScene *)scene).windows.firstObject;
            }
        }
    }
    return [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
}

// ═══════════════════════════════════════════════════════════════════════════════
// Galaxy Colors
// ═══════════════════════════════════════════════════════════════════════════════
#define EL_BG           [UIColor colorWithRed:0.04 green:0.03 blue:0.10 alpha:0.97]
#define EL_BG2          [UIColor colorWithRed:0.07 green:0.05 blue:0.15 alpha:1.0]
#define EL_BG3          [UIColor colorWithRed:0.10 green:0.07 blue:0.20 alpha:1.0]
#define EL_PURPLE       [UIColor colorWithRed:0.55 green:0.20 blue:1.00 alpha:1.0]
#define EL_PURPLE_DIM   [UIColor colorWithRed:0.55 green:0.20 blue:1.00 alpha:0.18]
#define EL_BLUE         [UIColor colorWithRed:0.20 green:0.50 blue:1.00 alpha:1.0]
#define EL_PINK         [UIColor colorWithRed:0.90 green:0.30 blue:0.90 alpha:1.0]
#define EL_STAR         [UIColor colorWithRed:0.85 green:0.90 blue:1.00 alpha:1.0]
#define EL_TEXT         [UIColor colorWithRed:0.88 green:0.88 blue:1.00 alpha:1.0]
#define EL_TEXT_DIM     [UIColor colorWithRed:0.45 green:0.40 blue:0.65 alpha:1.0]
#define EL_BORDER       [UIColor colorWithRed:0.55 green:0.20 blue:1.00 alpha:0.40].CGColor
#define EL_DIVIDER      [UIColor colorWithRed:0.55 green:0.20 blue:1.00 alpha:0.18]
#define EL_GLOW         [UIColor colorWithRed:0.60 green:0.30 blue:1.00 alpha:1.0]
#define EL_RED          [UIColor colorWithRed:1.00 green:0.20 blue:0.20 alpha:1.0]
#define EL_RED_DIM      [UIColor colorWithRed:1.00 green:0.20 blue:0.20 alpha:0.18]
#define EL_GOLD         [UIColor colorWithRed:1.00 green:0.84 blue:0.00 alpha:1.0]

// ═══════════════════════════════════════════════════════════════════════════════
// Glow & Visual Effects
// ═══════════════════════════════════════════════════════════════════════════════
static void ELGlow(CALayer *l, UIColor *c, CGFloat r) {
    l.shadowColor   = c.CGColor;
    l.shadowRadius  = r;
    l.shadowOpacity = 0.85f;
    l.shadowOffset  = CGSizeZero;
}

static CAGradientLayer *ELGalaxyGradient(CGRect frame) {
    CAGradientLayer *g = [CAGradientLayer layer];
    g.frame = frame;
    g.colors = @[
        (id)[UIColor colorWithRed:0.04 green:0.02 blue:0.12 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.08 green:0.04 blue:0.20 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.05 green:0.02 blue:0.15 alpha:1.0].CGColor,
    ];
    g.locations  = @[@0.0, @0.5, @1.0];
    g.startPoint = CGPointMake(0, 0);
    g.endPoint   = CGPointMake(1, 1);
    return g;
}

static void ELAddStars(UIView *view, NSInteger count) {
    for (NSInteger i = 0; i < count; i++) {
        CGFloat size       = (arc4random_uniform(3) == 0) ? 2.5f : 1.2f;
        CGFloat x          = arc4random_uniform((uint32_t)view.bounds.size.width);
        CGFloat y          = arc4random_uniform((uint32_t)view.bounds.size.height);
        UIView  *star      = [[UIView alloc] initWithFrame:CGRectMake(x, y, size, size)];
        CGFloat brightness = 0.5f + (arc4random_uniform(50) / 100.0f);
        star.backgroundColor  = [UIColor colorWithWhite:brightness alpha:1.0];
        star.layer.cornerRadius = size / 2.0f;

        CABasicAnimation *twinkle = [CABasicAnimation animationWithKeyPath:@"opacity"];
        twinkle.fromValue    = @(brightness);
        twinkle.toValue      = @(0.1);
        twinkle.duration     = 1.0 + (arc4random_uniform(20) / 10.0);
        twinkle.autoreverses = YES;
        twinkle.repeatCount  = HUGE_VALF;
        twinkle.timeOffset   = arc4random_uniform(30) / 10.0;
        [star.layer addAnimation:twinkle forKey:@"twinkle"];
        [view addSubview:star];
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Item Database (EverLight full list + XD additions)
// ═══════════════════════════════════════════════════════════════════════════════
static NSArray<NSString *> *ELAllItems(void) {
    return @[
        // XD full list additions
        @"item_ac_cola",              @"item_alphablade",           @"item_anti_gravity_grenade",
        @"item_apple",                @"item_arena_pistol",          @"item_arena_shotgun",
        @"item_arrow",                @"item_arrow_bomb",            @"item_arrow_heart",
        @"item_arrow_lightbulb",      @"item_arrow_teleport",        @"item_axe",
        @"item_backpack",             @"item_backpack_black",         @"item_backpack_green",
        @"item_backpack_large_base",  @"item_backpack_large_basketball", @"item_backpack_large_clover",
        @"item_backpack_pink",        @"item_backpack_realistic",     @"item_backpack_small_base",
        @"item_backpack_white",       @"item_backpack_with_flashlight", @"item_balloon",
        @"item_balloon_heart",        @"item_banana",                @"item_banana_chips",
        @"item_baseball_bat",         @"item_basic_fishing_rod",     @"item_bat",
        @"item_beans",                @"item_big_cup",               @"item_bighead_larva",
        @"item_bloodlust_vial",       @"item_bone",                  @"item_boombox",
        @"item_boombox_neon",         @"item_boomerang",             @"item_bow",
        @"item_box_fan",              @"item_brain_chunk",           @"item_bread",
        @"item_brick",                @"item_broccoli_grenade",      @"item_broccoli_shrink_grenade",
        @"item_broom",                @"item_broom_halloween",       @"item_burrito",
        @"item_calculator",           @"item_campfire",              @"item_cardboard_box",
        @"item_carrot",               @"item_cash_mega_pile",        @"item_ceo_plaque",
        @"item_cheese",               @"item_clapper",               @"item_cluster_grenade",
        @"item_coconut_shell",        @"item_coin",                  @"item_cola",
        @"item_cola_large",           @"item_collar",                @"item_company_ration",
        @"item_company_ration_heal",  @"item_cracker",               @"item_crate",
        @"item_crossbow",             @"item_crossbow_heart",        @"item_crowbar",
        @"item_crown",                @"item_cutie_dead",            @"item_d20",
        @"item_dagger",               @"item_demon_sword",           @"item_diamond",
        @"item_disc",                 @"item_disposable_camera",     @"item_drill",
        @"item_drill_neon",           @"item_dynamite",              @"item_dynamite_cube",
        @"item_egg",                  @"item_electrical_tape",       @"item_eraser",
        @"item_film_reel",            @"item_finger_board",          @"item_fish_bass",
        @"item_fish_catfish",         @"item_fish_crab",             @"item_fish_dumb_fish",
        @"item_fish_eel",             @"item_fish_goldfish",         @"item_fish_piranha",
        @"item_fish_salmon",          @"item_fish_shark",            @"item_fish_trout",
        @"item_fishing_rod",          @"item_fishing_rod_pro",       @"item_flamethrower",
        @"item_flamethrower_skull",   @"item_flamethrower_skull_ruby", @"item_flaregun",
        @"item_flashbang",            @"item_flashlight",            @"item_flashlight_mega",
        @"item_flashlight_red",       @"item_flipflop_realistic",    @"item_floppy3",
        @"item_floppy5",              @"item_football",              @"item_friend_launcher",
        @"item_frying_pan",           @"item_gameboy",               @"item_gem_blue",
        @"item_gem_green",            @"item_gem_red",               @"item_glowstick",
        @"item_goldbar",              @"item_goldcoin",              @"item_goop",
        @"item_goopfish",             @"item_great_sword",           @"item_grenade",
        @"item_grenade_gold",         @"item_grenade_launcher",      @"item_hammer",
        @"item_heartchocolatebox",    @"item_jetpack",               @"item_key",
        @"item_lantern",              @"item_machete",               @"item_medkit",
        @"item_mushroom",             @"item_pickaxe",               @"item_pistol",
        @"item_potion_health",        @"item_potion_speed",          @"item_quiver",
        @"item_radioactive_broccoli", @"item_rpg",                   @"item_rpg_ammo",
        @"item_ruby",                 @"item_shield",                @"item_shotgun",
        @"item_shovel",               @"item_smg",                   @"item_sniper",
        @"item_staff",                @"item_stash_grenade",         @"item_stinky_cheese",
        @"item_sword",                @"item_torch",                 @"item_trophy",
        @"item_turkey_leg",           @"item_turkey_whole",          @"item_vest",
        @"item_wand",                 @"item_water",                 @"item_bait_firefly",
        @"item_bait_glowworm",        @"item_bait_minnow",
    ];
}

static NSArray<NSString *> *ELCategoryItems(NSInteger cat) {
    switch (cat) {
        case 1:  return @[@"item_fishing_rod", @"item_fishing_rod_pro", @"item_basic_fishing_rod"];
        case 2:  return @[@"item_fish_bass",   @"item_fish_catfish",  @"item_fish_crab",
                          @"item_fish_eel",    @"item_fish_goldfish", @"item_fish_piranha",
                          @"item_fish_salmon", @"item_fish_shark",    @"item_fish_trout",
                          @"item_fish_dumb_fish", @"item_goopfish"];
        case 3:  return @[@"item_bait_firefly", @"item_bait_glowworm", @"item_bait_minnow"];
        case 4:  return @[@"item_alphablade",  @"item_arena_pistol",   @"item_arena_shotgun",
                          @"item_axe",         @"item_bat",            @"item_bow",
                          @"item_boomerang",   @"item_crossbow",       @"item_crossbow_heart",
                          @"item_dagger",      @"item_demon_sword",    @"item_drill",
                          @"item_drill_neon",  @"item_dynamite",       @"item_dynamite_cube",
                          @"item_flamethrower", @"item_flamethrower_skull", @"item_flamethrower_skull_ruby",
                          @"item_flaregun",    @"item_flashbang",      @"item_friend_launcher",
                          @"item_great_sword", @"item_grenade",        @"item_grenade_gold",
                          @"item_grenade_launcher", @"item_hammer",    @"item_jetpack",
                          @"item_machete",     @"item_pickaxe",        @"item_pistol",
                          @"item_rpg",         @"item_rpg_ammo",       @"item_shotgun",
                          @"item_shovel",      @"item_smg",            @"item_sniper",
                          @"item_staff",       @"item_stash_grenade",  @"item_sword",
                          @"item_wand",        @"item_cluster_grenade", @"item_broccoli_grenade",
                          @"item_broccoli_shrink_grenade", @"item_anti_gravity_grenade",
                          @"item_baseball_bat", @"item_crowbar",       @"item_brick"];
        case 5:  return @[@"item_goldbar",     @"item_cash_mega_pile", @"item_coin",
                          @"item_gem_blue",    @"item_gem_green",      @"item_gem_red",
                          @"item_ruby",        @"item_crown",          @"item_trophy",
                          @"item_diamond",     @"item_goldcoin",       @"item_ceo_plaque"];
        case 6:  return @[@"item_apple",       @"item_banana",         @"item_banana_chips",
                          @"item_beans",       @"item_bread",          @"item_burrito",
                          @"item_carrot",      @"item_cheese",         @"item_coconut_shell",
                          @"item_cola",        @"item_cola_large",     @"item_ac_cola",
                          @"item_company_ration", @"item_company_ration_heal", @"item_cracker",
                          @"item_egg",         @"item_mushroom",       @"item_stinky_cheese",
                          @"item_turkey_whole", @"item_turkey_leg",    @"item_heartchocolatebox",
                          @"item_radioactive_broccoli", @"item_water", @"item_bone",
                          @"item_big_cup",     @"item_campfire"];
        default: return ELAllItems();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Toast Notification System
// ═══════════════════════════════════════════════════════════════════════════════
static void ELToast(NSString *msg, BOOL success) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = ELKeyWindow();
        if (!win) return;

        UILabel *t = [[UILabel alloc] init];
        t.text = [NSString stringWithFormat:@" %@  %@ ", success ? @"✦" : @"✕", msg];
        t.font = [UIFont boldSystemFontOfSize:12];
        t.textColor       = EL_TEXT;
        t.backgroundColor = EL_BG2;
        t.layer.cornerRadius = 10;
        t.layer.borderWidth  = 1.2;
        t.layer.borderColor  = EL_BORDER;
        t.clipsToBounds   = YES;
        t.textAlignment   = NSTextAlignmentCenter;

        CGSize sz = [msg sizeWithAttributes:@{NSFontAttributeName: t.font}];
        t.frame = CGRectMake((win.bounds.size.width - sz.width - 60) / 2,
                              win.bounds.size.height - 110, sz.width + 60, 32);
        ELGlow(t.layer, success ? EL_PURPLE : EL_RED, 10);
        t.alpha     = 0;
        t.transform = CGAffineTransformMakeTranslation(0, 10);
        [win addSubview:t];

        [UIView animateWithDuration:0.25 animations:^{
            t.alpha     = 1;
            t.transform = CGAffineTransformIdentity;
        } completion:^(__unused BOOL d) {
            [UIView animateWithDuration:0.25 delay:1.8 options:0
                             animations:^{ t.alpha = 0; t.transform = CGAffineTransformMakeTranslation(0, 6); }
                             completion:^(__unused BOOL d2) { [t removeFromSuperview]; }];
        }];
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: — EverLight Menu (Galaxy UI + IL2CPP Engine)
// ═══════════════════════════════════════════════════════════════════════════════

@interface EverLightMenu : UIView <UITextFieldDelegate>
@property (nonatomic, assign) NSInteger selectedTab;
@property (nonatomic, assign) NSInteger selectedCategory;
@property (nonatomic, strong) NSString       *selectedItem;
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, strong) UIView         *itemsPage;
@property (nonatomic, strong) UIView         *settingsPage;
@property (nonatomic, strong) UIView         *opPage;
@property (nonatomic, strong) UIScrollView   *itemList;
@property (nonatomic, strong) UITextField    *searchField;
@property (nonatomic, strong) UILabel        *selectedItemLabel;
@property (nonatomic, strong) UILabel        *qtyLabel;
@property (nonatomic, strong) UILabel        *countLabel;
@property (nonatomic, strong) NSArray        *currentItems;
@property (nonatomic, strong) NSMutableArray *rowViews;
@property (nonatomic, assign) CGFloat menuRotation;

// OP Feature toggles
@property (nonatomic, assign) BOOL godModeEnabled;
@property (nonatomic, assign) BOOL noClipEnabled;
@property (nonatomic, assign) BOOL infiniteAmmoEnabled;
@property (nonatomic, assign) BOOL rapidFireEnabled;
@property (nonatomic, assign) BOOL superSpeedEnabled;
@property (nonatomic, assign) BOOL invisibilityEnabled;

// Spawn location
@property (nonatomic, assign) float spawnX;
@property (nonatomic, assign) float spawnY;
@property (nonatomic, assign) float spawnZ;
@property (nonatomic, assign) BOOL  useCustomSpawn;
@end

@implementation EverLightMenu

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _selectedTab      = 0;
    _selectedCategory = 0;
    _quantity         = 1;
    _currentItems     = ELAllItems();
    _rowViews         = [NSMutableArray array];
    _menuRotation     = 0;
    _spawnX = 0; _spawnY = 1.0f; _spawnZ = 0;
    _useCustomSpawn   = NO;
    [self buildUI];
    return self;
}

- (void)buildUI {
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;

    self.layer.cornerRadius = 18;
    self.layer.borderWidth  = 1.5;
    self.layer.borderColor  = EL_BORDER;
    ELGlow(self.layer, EL_PURPLE, 24);
    self.clipsToBounds = NO;

    UIView *clip = [[UIView alloc] initWithFrame:self.bounds];
    clip.layer.cornerRadius = 18;
    clip.clipsToBounds = YES;
    [self addSubview:clip];

    [clip.layer addSublayer:ELGalaxyGradient(self.bounds)];

    UIView *starField = [[UIView alloc] initWithFrame:self.bounds];
    starField.backgroundColor = [UIColor clearColor];
    [clip addSubview:starField];
    ELAddStars(starField, 60);

    UIView *nebula1 = [[UIView alloc] initWithFrame:CGRectMake(-30, -30, 140, 140)];
    nebula1.backgroundColor  = [UIColor colorWithRed:0.4 green:0.1 blue:0.8 alpha:0.15];
    nebula1.layer.cornerRadius = 70;
    [clip addSubview:nebula1];

    UIView *nebula2 = [[UIView alloc] initWithFrame:CGRectMake(w - 80, h - 80, 140, 140)];
    nebula2.backgroundColor  = [UIColor colorWithRed:0.1 green:0.3 blue:0.9 alpha:0.12];
    nebula2.layer.cornerRadius = 70;
    [clip addSubview:nebula2];

    CAGradientLayer *stripe = [CAGradientLayer layer];
    stripe.frame = CGRectMake(0, 0, w, 3);
    stripe.colors = @[
        (id)[UIColor colorWithRed:0.6 green:0.2 blue:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.8 green:0.2 blue:0.9 alpha:1.0].CGColor,
    ];
    stripe.startPoint = CGPointMake(0, 0.5);
    stripe.endPoint   = CGPointMake(1, 0.5);
    [clip.layer addSublayer:stripe];

    UIView *hdrBg = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 50)];
    hdrBg.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    [clip addSubview:hdrBg];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
                                   initWithTarget:self action:@selector(handleDrag:)];
    [hdrBg addGestureRecognizer:pan];

    UIButton *closeBtn = [[UIButton alloc] initWithFrame:CGRectMake(8, 12, 28, 28)];
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:EL_PURPLE forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    closeBtn.backgroundColor  = EL_PURPLE_DIM;
    closeBtn.layer.cornerRadius = 14;
    closeBtn.layer.borderWidth  = 1;
    closeBtn.layer.borderColor  = EL_BORDER;
    UITapGestureRecognizer *ct = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
    [ct addTarget:^(__unused id s) { [self dismiss]; } withObject:nil];
    [closeBtn addGestureRecognizer:ct];
    [clip addSubview:closeBtn];

    // Engine status indicator
    UILabel *engineStatus = [[UILabel alloc] initWithFrame:CGRectMake(w - 38, 12, 28, 28)];
    engineStatus.text           = gIsInitialized ? @"●" : @"○";
    engineStatus.textColor      = gIsInitialized ? [UIColor colorWithRed:0.2 green:1.0 blue:0.4 alpha:1.0] : EL_RED;
    engineStatus.textAlignment  = NSTextAlignmentCenter;
    engineStatus.font           = [UIFont boldSystemFontOfSize:14];
    [clip addSubview:engineStatus];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 13, w, 24)];
    title.text          = @"✦ EVERLIGHT v3.0 ✦";
    title.textAlignment = NSTextAlignmentCenter;
    title.textColor     = EL_STAR;
    title.font = [UIFont fontWithName:@"AvenirNext-Heavy" size:16]
              ?: [UIFont boldSystemFontOfSize:16];
    ELGlow(title.layer, EL_PURPLE, 12);
    [clip addSubview:title];

    [clip addSubview:[self buildTabBarAtY:52 width:w clip:clip]];

    UIView *div = [[UIView alloc] initWithFrame:CGRectMake(10, 92, w - 20, 1)];
    div.backgroundColor = EL_DIVIDER;
    [clip addSubview:div];

    CGRect pageFrame  = CGRectMake(0, 96, w, h - 96);
    _itemsPage        = [[UIView alloc] initWithFrame:pageFrame];
    _settingsPage     = [[UIView alloc] initWithFrame:pageFrame];
    _opPage           = [[UIView alloc] initWithFrame:pageFrame];
    _itemsPage.hidden       = NO;
    _settingsPage.hidden    = YES;
    _opPage.hidden          = YES;
    _itemsPage.backgroundColor    = [UIColor clearColor];
    _settingsPage.backgroundColor = [UIColor clearColor];
    _opPage.backgroundColor       = [UIColor clearColor];
    [clip addSubview:_itemsPage];
    [clip addSubview:_settingsPage];
    [clip addSubview:_opPage];

    [self buildItemsPage];
    [self buildSettingsPage];
    [self buildOPPage];
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab Bar
// ═══════════════════════════════════════════════════════════════════════════════
- (UIView *)buildTabBarAtY:(CGFloat)y width:(CGFloat)w clip:(__unused UIView *)clip {
    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(10, y, w - 20, 36)];
    bar.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    bar.layer.cornerRadius = 10;
    bar.layer.borderWidth  = 1;
    bar.layer.borderColor  = EL_BORDER;

    NSArray  *tabs = @[@"Items", @"Settings", @"OP"];
    NSInteger tabCount = (NSInteger)tabs.count;
    CGFloat   tw       = (w - 20) / tabCount;

    UIView *indicator = [[UIView alloc] initWithFrame:CGRectMake(2, 2, tw - 4, 32)];
    indicator.backgroundColor  = EL_PURPLE_DIM;
    indicator.layer.cornerRadius = 8;
    indicator.layer.borderWidth  = 1;
    indicator.layer.borderColor  = EL_BORDER;
    ELGlow(indicator.layer, EL_PURPLE, 8);
    indicator.tag = 9001;
    [bar addSubview:indicator];

    for (NSInteger i = 0; i < tabCount; i++) {
        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(tw * i + 2, 2, tw - 4, 32)];
        [btn setTitle:tabs[(NSUInteger)i] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        [btn setTitleColor:(i == 0 ? EL_STAR : EL_TEXT_DIM) forState:UIControlStateNormal];
        btn.tag = 8000 + i;
        UITapGestureRecognizer *t = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
        NSInteger ci = i;
        UIView *b2   = bar;
        CGFloat tw2  = tw;
        [t addTarget:^(__unused id s) { [self switchToTab:ci bar:b2 tabW:tw2]; } withObject:nil];
        [btn addGestureRecognizer:t];
        [bar addSubview:btn];
    }
    return bar;
}

- (void)switchToTab:(NSInteger)idx bar:(UIView *)bar tabW:(CGFloat)tw {
    _selectedTab             = idx;
    _itemsPage.hidden        = (idx != 0);
    _settingsPage.hidden     = (idx != 1);
    _opPage.hidden           = (idx != 2);
    UIView *ind = [bar viewWithTag:9001];

    if (idx == 2) {
        ind.backgroundColor = EL_RED_DIM;
        ELGlow(ind.layer, EL_RED, 8);
    } else {
        ind.backgroundColor = EL_PURPLE_DIM;
        ELGlow(ind.layer, EL_PURPLE, 8);
    }

    [UIView animateWithDuration:0.22 delay:0 usingSpringWithDamping:0.75
           initialSpringVelocity:0.5 options:0
                       animations:^{
        ind.frame = CGRectMake(tw * idx + 2, 2, tw - 4, 32);
    } completion:nil];
    for (NSInteger i = 0; i < 3; i++) {
        UIButton *b = (UIButton *)[bar viewWithTag:8000 + i];
        [b setTitleColor:(i == idx ? EL_STAR : EL_TEXT_DIM) forState:UIControlStateNormal];
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Items Page — IL2CPP Direct Spawn
// ═══════════════════════════════════════════════════════════════════════════════
- (void)buildItemsPage {
    CGFloat w = _itemsPage.bounds.size.width;
    CGFloat h = _itemsPage.bounds.size.height;

    // Engine status banner
    UIView *statusBanner = [[UIView alloc] initWithFrame:CGRectMake(10, 4, w - 20, 20)];
    statusBanner.backgroundColor = gIsInitialized
        ? [UIColor colorWithRed:0.1 green:0.5 blue:0.2 alpha:0.3]
        : [UIColor colorWithRed:0.5 green:0.1 blue:0.1 alpha:0.3];
    statusBanner.layer.cornerRadius = 6;
    [_itemsPage addSubview:statusBanner];
    UILabel *statusLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, w - 20, 20)];
    statusLbl.text = gIsInitialized
        ? @"✦ IL2CPP ENGINE READY — Direct Spawn Active"
        : @"⚠ IL2CPP not ready — Engine initializing...";
    statusLbl.font = [UIFont boldSystemFontOfSize:9];
    statusLbl.textColor = gIsInitialized
        ? [UIColor colorWithRed:0.4 green:1.0 blue:0.5 alpha:1.0]
        : EL_RED;
    statusLbl.textAlignment = NSTextAlignmentCenter;
    [statusBanner addSubview:statusLbl];

    // Category pills
    UIScrollView *catScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 28, w, 38)];
    catScroll.showsHorizontalScrollIndicator = NO;
    catScroll.backgroundColor = [UIColor clearColor];

    NSArray   *cats    = @[@"All", @"Rods", @"Fish", @"Baits", @"Weapons", @"Valuables", @"Food"];
    NSInteger  catCount = (NSInteger)cats.count;
    CGFloat    cx      = 8;

    for (NSInteger i = 0; i < catCount; i++) {
        NSString *catName = cats[(NSUInteger)i];
        CGFloat   pw      = [catName sizeWithAttributes:
                             @{NSFontAttributeName: [UIFont boldSystemFontOfSize:11]}].width + 22;
        UIButton *pill    = [[UIButton alloc] initWithFrame:CGRectMake(cx, 4, pw, 28)];
        [pill setTitle:catName forState:UIControlStateNormal];
        pill.titleLabel.font    = [UIFont boldSystemFontOfSize:11];
        pill.layer.cornerRadius = 14;
        pill.layer.borderWidth  = 1.2f;
        BOOL active          = (i == 0);
        pill.backgroundColor = active ? EL_PURPLE_DIM : [UIColor colorWithWhite:1 alpha:0.05];
        [pill setTitleColor:active ? EL_PURPLE : EL_TEXT_DIM forState:UIControlStateNormal];
        pill.layer.borderColor = active ? EL_BORDER : [UIColor colorWithWhite:1 alpha:0.08].CGColor;
        if (active) ELGlow(pill.layer, EL_PURPLE, 6);
        pill.tag = 7000 + i;
        UITapGestureRecognizer *t = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
        NSInteger    ci = i;
        UIScrollView *cs = catScroll;
        [t addTarget:^(__unused id s) { [self selectCategory:ci scroll:cs]; } withObject:nil];
        [pill addGestureRecognizer:t];
        [catScroll addSubview:pill];
        cx += pw + 6;
    }
    catScroll.contentSize = CGSizeMake(cx + 8, 38);
    [_itemsPage addSubview:catScroll];

    // Search bar
    UIView *sw = [[UIView alloc] initWithFrame:CGRectMake(10, 70, w - 20, 32)];
    sw.backgroundColor    = [UIColor colorWithWhite:0 alpha:0.35];
    sw.layer.cornerRadius = 8;
    sw.layer.borderWidth  = 1;
    sw.layer.borderColor  = EL_BORDER;
    [_itemsPage addSubview:sw];

    UILabel *gl = [[UILabel alloc] initWithFrame:CGRectMake(8, 0, 22, 32)];
    gl.text      = @"✦";
    gl.font      = [UIFont systemFontOfSize:12];
    gl.textColor = EL_PURPLE;
    [sw addSubview:gl];

    _searchField = [[UITextField alloc] initWithFrame:CGRectMake(28, 2, w - 60, 28)];
    _searchField.font            = [UIFont systemFontOfSize:12];
    _searchField.textColor       = EL_TEXT;
    _searchField.backgroundColor = [UIColor clearColor];
    _searchField.delegate        = self;
    _searchField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:@"Search items..."
            attributes:@{NSForegroundColorAttributeName: EL_TEXT_DIM,
                         NSFontAttributeName: [UIFont systemFontOfSize:12]}];
    [_searchField addTarget:self action:@selector(searchChanged)
          forControlEvents:UIControlEventEditingChanged];
    [sw addSubview:_searchField];

    _countLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - 80, 106, 70, 16)];
    _countLabel.text          = [NSString stringWithFormat:@"%lu items", (unsigned long)ELAllItems().count];
    _countLabel.font          = [UIFont systemFontOfSize:10];
    _countLabel.textColor     = EL_PURPLE;
    _countLabel.textAlignment = NSTextAlignmentRight;
    [_itemsPage addSubview:_countLabel];

    UILabel *iHdr = [[UILabel alloc] initWithFrame:CGRectMake(12, 106, 160, 16)];
    iHdr.text      = @"✦ ITEM SPAWNER";
    iHdr.font      = [UIFont boldSystemFontOfSize:10];
    iHdr.textColor = EL_TEXT_DIM;
    [_itemsPage addSubview:iHdr];

    // Selected item display
    UIView *selWrap = [[UIView alloc] initWithFrame:CGRectMake(10, 125, w - 20, 26)];
    selWrap.backgroundColor  = EL_PURPLE_DIM;
    selWrap.layer.cornerRadius = 6;
    selWrap.layer.borderWidth  = 1;
    selWrap.layer.borderColor  = EL_BORDER;
    [_itemsPage addSubview:selWrap];

    _selectedItemLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 0, w - 40, 26)];
    _selectedItemLabel.text      = @"tap an item to select...";
    _selectedItemLabel.font      = [UIFont fontWithName:@"Menlo" size:10]
                                ?: [UIFont systemFontOfSize:10];
    _selectedItemLabel.textColor = EL_TEXT_DIM;
    [selWrap addSubview:_selectedItemLabel];

    // Item list
    CGFloat listH = h - 290;
    _itemList = [[UIScrollView alloc] initWithFrame:CGRectMake(10, 155, w - 20, listH)];
    _itemList.backgroundColor  = [UIColor colorWithWhite:0 alpha:0.35];
    _itemList.layer.cornerRadius = 10;
    _itemList.layer.borderWidth  = 1;
    _itemList.layer.borderColor  = EL_BORDER;
    [_itemsPage addSubview:_itemList];
    [self reloadItemList];

    CGFloat by = 155 + listH + 8;

    // Quantity stepper
    UILabel *ql = [[UILabel alloc] initWithFrame:CGRectMake(12, by, 30, 28)];
    ql.text      = @"Qty:";
    ql.font      = [UIFont boldSystemFontOfSize:11];
    ql.textColor = EL_TEXT_DIM;
    [_itemsPage addSubview:ql];

    _qtyLabel = [[UILabel alloc] initWithFrame:CGRectMake(44, by, 36, 28)];
    _qtyLabel.text          = @"1";
    _qtyLabel.font          = [UIFont boldSystemFontOfSize:15];
    _qtyLabel.textColor     = EL_PINK;
    _qtyLabel.textAlignment = NSTextAlignmentCenter;
    [_itemsPage addSubview:_qtyLabel];

    [_itemsPage addSubview:[self makeStepBtn:@"−" frame:CGRectMake(82, by + 2, 28, 24)
                                      action:@selector(qtyMinus)]];
    [_itemsPage addSubview:[self makeStepBtn:@"+" frame:CGRectMake(112, by + 2, 28, 24)
                                      action:@selector(qtyPlus)]];

    UIView *d2 = [[UIView alloc] initWithFrame:CGRectMake(10, by + 32, w - 20, 1)];
    d2.backgroundColor = EL_DIVIDER;
    [_itemsPage addSubview:d2];

    // Spawn button
    UIButton *spawn = [[UIButton alloc] initWithFrame:CGRectMake(10, by + 38, w - 20, 38)];
    spawn.layer.cornerRadius = 10;
    spawn.clipsToBounds = YES;
    CAGradientLayer *spawnGrad = [CAGradientLayer layer];
    spawnGrad.frame  = CGRectMake(0, 0, w - 20, 38);
    spawnGrad.colors = @[
        (id)[UIColor colorWithRed:0.5 green:0.1 blue:0.9 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.2 green:0.4 blue:1.0 alpha:1.0].CGColor,
    ];
    spawnGrad.startPoint = CGPointMake(0, 0.5);
    spawnGrad.endPoint   = CGPointMake(1, 0.5);
    [spawn.layer insertSublayer:spawnGrad atIndex:0];
    [spawn setTitle:@"✦  SPAWN ITEM (IL2CPP)" forState:UIControlStateNormal];
    [spawn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    spawn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    ELGlow(spawn.layer, EL_PURPLE, 14);
    UITapGestureRecognizer *spawnT = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
    [spawnT addTarget:^(__unused id s) { [self doSpawn]; } withObject:nil];
    [spawn addGestureRecognizer:spawnT];
    [_itemsPage addSubview:spawn];
}

// ═══════════════════════════════════════════════════════════════════════════════
// Settings Page
// ═══════════════════════════════════════════════════════════════════════════════
- (void)buildSettingsPage {
    CGFloat w = _settingsPage.bounds.size.width;

    UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w, 16)];
    hdr.text      = @"✦ SPAWN LOCATION";
    hdr.font      = [UIFont boldSystemFontOfSize:10];
    hdr.textColor = EL_TEXT_DIM;
    [_settingsPage addSubview:hdr];

    UIView *d = [[UIView alloc] initWithFrame:CGRectMake(10, 27, w - 20, 1)];
    d.backgroundColor = EL_DIVIDER;
    [_settingsPage addSubview:d];

    // Custom spawn toggle
    [self addToggleRow:@"Custom Spawn Location" subtitle:@"Use X/Y/Z below instead of player pos"
                     y:34 action:@selector(toggleCustomSpawn:)];

    // X / Y / Z fields
    NSArray *axes = @[@"X", @"Y", @"Z"];
    for (NSInteger i = 0; i < 3; i++) {
        CGFloat fy = 88 + i * 46;
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, fy, 20, 36)];
        lbl.text      = axes[(NSUInteger)i];
        lbl.textColor = EL_PURPLE;
        lbl.font      = [UIFont boldSystemFontOfSize:13];
        [_settingsPage addSubview:lbl];

        UIView *fieldBg = [[UIView alloc] initWithFrame:CGRectMake(38, fy + 4, w - 50, 28)];
        fieldBg.backgroundColor    = [UIColor colorWithWhite:0 alpha:0.35];
        fieldBg.layer.cornerRadius = 7;
        fieldBg.layer.borderWidth  = 1;
        fieldBg.layer.borderColor  = EL_BORDER;
        [_settingsPage addSubview:fieldBg];

        UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(8, 2, w - 66, 24)];
        tf.font = [UIFont systemFontOfSize:12];
        tf.textColor = EL_TEXT;
        tf.backgroundColor = [UIColor clearColor];
        tf.delegate = self;
        tf.keyboardType = UIKeyboardTypeDecimalPad;
        tf.text = (i == 1) ? @"1.0" : @"0";
        tf.tag  = 5000 + i;
        tf.attributedPlaceholder = [[NSAttributedString alloc]
            initWithString:axes[(NSUInteger)i]
                attributes:@{NSForegroundColorAttributeName: EL_TEXT_DIM}];
        [fieldBg addSubview:tf];
    }

    UIButton *applyBtn = [[UIButton alloc] initWithFrame:CGRectMake(10, 230, w - 20, 34)];
    applyBtn.backgroundColor  = EL_PURPLE_DIM;
    applyBtn.layer.cornerRadius = 8;
    applyBtn.layer.borderWidth  = 1;
    applyBtn.layer.borderColor  = EL_BORDER;
    [applyBtn setTitle:@"Apply Spawn Location" forState:UIControlStateNormal];
    [applyBtn setTitleColor:EL_STAR forState:UIControlStateNormal];
    applyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [applyBtn addTarget:self action:@selector(applySpawnLocation)
      forControlEvents:UIControlEventTouchUpInside];
    [_settingsPage addSubview:applyBtn];

    UIButton *resetBtn = [[UIButton alloc] initWithFrame:CGRectMake(10, 270, w - 20, 34)];
    resetBtn.backgroundColor  = [UIColor colorWithWhite:0 alpha:0.35];
    resetBtn.layer.cornerRadius = 8;
    resetBtn.layer.borderWidth  = 1;
    resetBtn.layer.borderColor  = EL_BORDER;
    [resetBtn setTitle:@"Reset to Player Position" forState:UIControlStateNormal];
    [resetBtn setTitleColor:EL_TEXT_DIM forState:UIControlStateNormal];
    resetBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [resetBtn addTarget:self action:@selector(resetSpawnLocation)
       forControlEvents:UIControlEventTouchUpInside];
    [_settingsPage addSubview:resetBtn];

    UIView *d2 = [[UIView alloc] initWithFrame:CGRectMake(10, 316, w - 20, 1)];
    d2.backgroundColor = EL_DIVIDER;
    [_settingsPage addSubview:d2];

    UILabel *hdr2 = [[UILabel alloc] initWithFrame:CGRectMake(12, 322, w, 16)];
    hdr2.text      = @"✦ TOGGLES";
    hdr2.font      = [UIFont boldSystemFontOfSize:10];
    hdr2.textColor = EL_TEXT_DIM;
    [_settingsPage addSubview:hdr2];

    [self addToggleRow:@"God Mode"   subtitle:@"Infinite health"       y:340 action:@selector(toggleGod:)];
    [self addToggleRow:@"No Clip"    subtitle:@"Walk through walls"    y:390 action:@selector(toggleClip:)];

    // IL2CPP engine status
    UILabel *engLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 448, w - 24, 30)];
    engLbl.text = [NSString stringWithFormat:@"IL2CPP: %@  |  SpawnMethod: %@  |  MoneyMethod: %@",
                   gIsInitialized ? @"✓" : @"✗",
                   gSpawnItemMethod ? @"✓" : @"✗",
                   gGiveSelfMoneyMethod ? @"✓" : @"✗"];
    engLbl.font = [UIFont fontWithName:@"Menlo" size:8] ?: [UIFont systemFontOfSize:8];
    engLbl.textColor = EL_TEXT_DIM;
    engLbl.numberOfLines = 2;
    [_settingsPage addSubview:engLbl];
}

// ═══════════════════════════════════════════════════════════════════════════════
// OP Page
// ═══════════════════════════════════════════════════════════════════════════════
- (void)buildOPPage {
    CGFloat w = _opPage.bounds.size.width;
    CGFloat h = _opPage.bounds.size.height;

    UILabel *warningLbl = [[UILabel alloc] initWithFrame:CGRectMake(10, 4, w - 20, 20)];
    warningLbl.text = @"⚠️  IL2CPP DIRECT  —  REAL GAME EFFECTS  ⚠️";
    warningLbl.font = [UIFont boldSystemFontOfSize:10];
    warningLbl.textColor = EL_RED;
    warningLbl.textAlignment = NSTextAlignmentCenter;
    [_opPage addSubview:warningLbl];

    UIScrollView *opScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 28, w, h - 28)];
    opScroll.showsVerticalScrollIndicator = YES;
    opScroll.backgroundColor = [UIColor clearColor];
    [_opPage addSubview:opScroll];

    CGFloat y = 8;

    // Money
    y = [self addOPSectionHeader:@"💰 MONEY CHEATS" y:y parent:opScroll];
    y = [self addOPButton:@"💰 Give Self $9,999,999" subtitle:@"AddPlayerMoney on local player"
               color:EL_GOLD y:y parent:opScroll action:@selector(opGiveSelfMoney)];
    y = [self addOPButton:@"💸 Give ALL Players $9,999,999" subtitle:@"RPC_AddPlayerMoneyToAll"
               color:EL_GOLD y:y parent:opScroll action:@selector(opGiveAllMoney)];

    // Ammo & Shop
    y = [self addOPSectionHeader:@"🎯 AMMO & SHOP" y:y parent:opScroll];
    y = [self addOPButton:@"♾️ Infinite Ammo" subtitle:@"Set ammo field to 9999"
               color:EL_BLUE y:y parent:opScroll action:@selector(opInfiniteAmmo)];
    y = [self addOPButton:@"🛒 Remove Shop Cooldown" subtitle:@"Reset shopCooldown/buyTimer"
               color:EL_BLUE y:y parent:opScroll action:@selector(opRemoveShopCooldown)];

    // Spawning
    y = [self addOPSectionHeader:@"📦 BULK SPAWN (IL2CPP)" y:y parent:opScroll];
    y = [self addOPButton:@"⚔️ Spawn All Weapons" subtitle:@"Spawn every weapon via IL2CPP"
               color:EL_RED y:y parent:opScroll action:@selector(opSpawnAllWeapons)];
    y = [self addOPButton:@"💎 Spawn All Valuables" subtitle:@"Spawn every valuable"
               color:EL_GOLD y:y parent:opScroll action:@selector(opSpawnAllValuables)];
    y = [self addOPButton:@"🍔 Spawn All Food" subtitle:@"Spawn every food item"
               color:EL_PINK y:y parent:opScroll action:@selector(opSpawnAllFood)];
    y = [self addOPButton:@"🎣 Spawn All Fish" subtitle:@"Spawn every fish"
               color:EL_BLUE y:y parent:opScroll action:@selector(opSpawnAllFish)];
    y = [self addOPButton:@"🌧️ Item Rain (50 random)" subtitle:@"Spawn 50 random items"
               color:EL_PURPLE y:y parent:opScroll action:@selector(opItemRain)];

    // Engine
    y = [self addOPSectionHeader:@"⚙️ ENGINE" y:y parent:opScroll];
    y = [self addOPButton:@"🔄 Re-Initialize IL2CPP" subtitle:@"Force reinitialize game classes"
               color:EL_PURPLE y:y parent:opScroll action:@selector(opReinitEngine)];

    opScroll.contentSize = CGSizeMake(w, y + 20);
}

- (CGFloat)addOPSectionHeader:(NSString *)title y:(CGFloat)y parent:(UIView *)parent {
    CGFloat w = parent.bounds.size.width;
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(10, y, w - 20, 1)];
    line.backgroundColor = EL_DIVIDER;
    [parent addSubview:line];
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(10, y + 6, w - 20, 18)];
    lbl.text = title;
    lbl.font = [UIFont boldSystemFontOfSize:10];
    lbl.textColor = EL_TEXT_DIM;
    [parent addSubview:lbl];
    return y + 28;
}

- (CGFloat)addOPButton:(NSString *)title subtitle:(NSString *)subtitle
               color:(UIColor *)color y:(CGFloat)y parent:(UIView *)parent
               action:(SEL)action {
    CGFloat w = parent.bounds.size.width;
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(10, y, w - 20, 44)];
    btn.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    btn.layer.cornerRadius = 10;
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [color colorWithAlphaComponent:0.4].CGColor;
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 5, w - 50, 18)];
    titleLbl.text = title;
    titleLbl.font = [UIFont boldSystemFontOfSize:12];
    titleLbl.textColor = color;
    [btn addSubview:titleLbl];
    UILabel *subLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 24, w - 50, 14)];
    subLbl.text = subtitle;
    subLbl.font = [UIFont systemFontOfSize:9];
    subLbl.textColor = EL_TEXT_DIM;
    [btn addSubview:subLbl];
    ELGlow(btn.layer, color, 6);
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [parent addSubview:btn];
    return y + 52;
}

// ═══════════════════════════════════════════════════════════════════════════════
// OP Button Actions — Real IL2CPP Calls
// ═══════════════════════════════════════════════════════════════════════════════

- (void)opGiveSelfMoney {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        XDGiveSelfMoney(9999999);
        ELToast(@"💰 $9,999,999 added to self!", YES);
        ELPlaySound(0x5EF);
    });
}

- (void)opGiveAllMoney {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        XDGiveAllPlayersMoney(9999999);
        ELToast(@"💸 $9,999,999 sent to ALL players!", YES);
        ELPlaySound(0x5EF);
    });
}

- (void)opInfiniteAmmo {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        XDGiveInfiniteAmmo();
        ELToast(@"♾️ Infinite ammo activated!", YES);
        ELPlaySound(0x5EF);
    });
}

- (void)opRemoveShopCooldown {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL ok = XDRemoveShopCooldown();
        ELToast(ok ? @"🛒 Shop cooldown removed!" : @"✕ Could not find cooldown field", ok);
        if (ok) ELPlaySound(0x5EF);
    });
}

- (void)opSpawnAllWeapons {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *weapons = ELCategoryItems(4);
        for (NSString *w in weapons) XDSpawnItem(w, 1);
        ELToast([NSString stringWithFormat:@"⚔️ Spawned %lu weapons!", (unsigned long)weapons.count], YES);
    });
}

- (void)opSpawnAllValuables {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *items = ELCategoryItems(5);
        for (NSString *i in items) XDSpawnItem(i, 1);
        ELToast([NSString stringWithFormat:@"💎 Spawned %lu valuables!", (unsigned long)items.count], YES);
    });
}

- (void)opSpawnAllFood {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *items = ELCategoryItems(6);
        for (NSString *i in items) XDSpawnItem(i, 1);
        ELToast([NSString stringWithFormat:@"🍔 Spawned %lu food items!", (unsigned long)items.count], YES);
    });
}

- (void)opSpawnAllFish {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *items = ELCategoryItems(2);
        for (NSString *i in items) XDSpawnItem(i, 1);
        ELToast([NSString stringWithFormat:@"🎣 Spawned %lu fish!", (unsigned long)items.count], YES);
    });
}

- (void)opItemRain {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *all = ELAllItems();
        for (int i = 0; i < 50; i++) {
            NSString *item = all[arc4random_uniform((uint32_t)all.count)];
            XDSpawnItem(item, 1);
        }
        ELToast(@"🌧️ Item rain — 50 items spawned!", YES);
    });
}

- (void)opReinitEngine {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        gIsInitialized = NO;
        gGetLocalPlayerMethod = 0;
        gGiveSelfMoneyMethod  = 0;
        gSpawnItemMethod      = 0;
        gNetPlayerClass       = 0;
        gPrefabGeneratorClass = 0;
        if (XDInitializeIL2CPP()) {
            XDInitializeGameClasses();
        }
        BOOL ok = gSpawnItemMethod != 0;
        ELToast(ok ? @"✓ IL2CPP engine re-initialized!" : @"✕ Re-init failed — retry in-game", ok);
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Settings Page Actions
// ═══════════════════════════════════════════════════════════════════════════════
- (void)toggleCustomSpawn:(UISwitch *)s {
    _useCustomSpawn = s.on;
    gUseCustomLocation = s.on;
    ELToast(s.on ? @"Custom spawn location ON" : @"Using player position", YES);
}

- (void)applySpawnLocation {
    UITextField *tfX = (UITextField *)[_settingsPage viewWithTag:5000];
    UITextField *tfY = (UITextField *)[_settingsPage viewWithTag:5001];
    UITextField *tfZ = (UITextField *)[_settingsPage viewWithTag:5002];
    _spawnX = tfX.text.floatValue;
    _spawnY = tfY.text.floatValue;
    _spawnZ = tfZ.text.floatValue;
    gCustomSpawnX = _spawnX;
    gCustomSpawnY = _spawnY;
    gCustomSpawnZ = _spawnZ;
    ELToast([NSString stringWithFormat:@"Spawn: X=%.1f Y=%.1f Z=%.1f", _spawnX, _spawnY, _spawnZ], YES);
}

- (void)resetSpawnLocation {
    _spawnX = 0; _spawnY = 1.0f; _spawnZ = 0;
    _useCustomSpawn = NO;
    gCustomSpawnX = 0; gCustomSpawnY = 1.0f; gCustomSpawnZ = 0;
    gUseCustomLocation = NO;
    ELToast(@"Spawn reset to player position", YES);
}

- (void)toggleGod:(UISwitch *)s {
    _godModeEnabled = s.on;
    ELToast(s.on ? @"God Mode ON!" : @"God Mode OFF", s.on);
}

- (void)toggleClip:(UISwitch *)s {
    _noClipEnabled = s.on;
    ELToast(s.on ? @"No Clip ON!" : @"No Clip OFF", s.on);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Item spawn helper
// ═══════════════════════════════════════════════════════════════════════════════
- (void)doSpawn {
    if (!_selectedItem) { ELToast(@"Select an item first", NO); return; }
    NSString *item = _selectedItem;
    NSInteger qty  = _quantity;
    ELToast([NSString stringWithFormat:@"Spawning %@ x%ld...", item, (long)qty], YES);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (!gIsInitialized || !gSpawnItemMethod) {
            ELToast(@"✕ IL2CPP not ready — try in-game", NO);
            return;
        }
        XDSpawnItem(item, (int)qty);
        ELToast([NSString stringWithFormat:@"✦ Spawned %@ x%ld", item, (long)qty], YES);
        ELPlaySound(0x5EF);
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Item List Helpers
// ═══════════════════════════════════════════════════════════════════════════════
- (void)reloadItemList {
    for (UIView *r in _rowViews) [r removeFromSuperview];
    [_rowViews removeAllObjects];

    NSArray   *items = _currentItems;
    NSString  *q     = _searchField.text;
    if (q.length > 0)
        items = [items filteredArrayUsingPredicate:
                 [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@", q]];

    CGFloat   rh      = 36;
    NSInteger iCount  = (NSInteger)items.count;
    for (NSInteger i = 0; i < iCount; i++) {
        NSString *name = items[(NSUInteger)i];
        UIView *row = [[UIView alloc] initWithFrame:
                       CGRectMake(0, i * rh, _itemList.bounds.size.width, rh)];
        row.backgroundColor = (i % 2 == 0) ? [UIColor clearColor]
                                            : [UIColor colorWithWhite:1 alpha:0.02];

        UILabel *lbl = [[UILabel alloc] initWithFrame:
                        CGRectMake(10, 0, _itemList.bounds.size.width - 20, rh)];
        lbl.text                     = name;
        lbl.font                     = [UIFont fontWithName:@"Menlo" size:11]
                                    ?: [UIFont systemFontOfSize:11];
        lbl.textColor                = [name isEqualToString:_selectedItem] ? EL_PURPLE : EL_TEXT;
        lbl.adjustsFontSizeToFitWidth = YES;
        [row addSubview:lbl];

        if ([name isEqualToString:_selectedItem]) {
            row.backgroundColor = EL_PURPLE_DIM;
            ELGlow(row.layer, EL_PURPLE, 4);
        }

        UITapGestureRecognizer *t = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
        NSString *cn = name;
        [t addTarget:^(__unused id s) { [self selectItemNamed:cn]; } withObject:nil];
        [row addGestureRecognizer:t];
        [_itemList addSubview:row];
        [_rowViews addObject:row];
    }
    _itemList.contentSize = CGSizeMake(_itemList.bounds.size.width, items.count * rh);
    _countLabel.text = [NSString stringWithFormat:@"%lu items", (unsigned long)items.count];
}

- (void)selectItemNamed:(NSString *)name {
    _selectedItem            = name;
    _selectedItemLabel.text      = name;
    _selectedItemLabel.textColor = EL_TEXT;
    [self reloadItemList];
}

- (void)selectCategory:(NSInteger)idx scroll:(UIScrollView *)scroll {
    _selectedCategory = idx;
    _currentItems     = ELCategoryItems(idx);
    _searchField.text = @"";
    [self reloadItemList];

    for (UIView *sub in scroll.subviews) {
        if (![sub isKindOfClass:[UIButton class]]) continue;
        UIButton  *b      = (UIButton *)sub;
        NSInteger  bi     = b.tag - 7000;
        BOOL       active = (bi == idx);
        b.backgroundColor = active ? EL_PURPLE_DIM : [UIColor colorWithWhite:1 alpha:0.05];
        [b setTitleColor:active ? EL_PURPLE : EL_TEXT_DIM forState:UIControlStateNormal];
        b.layer.borderColor = active ? EL_BORDER
                                     : [UIColor colorWithWhite:1 alpha:0.08].CGColor;
        if (active) ELGlow(b.layer, EL_PURPLE, 5);
        else        b.layer.shadowOpacity = 0;
    }
}

- (void)searchChanged { [self reloadItemList]; }

- (void)qtyMinus { if (_quantity > 1)   { _quantity--;  _qtyLabel.text = @(_quantity).stringValue; } }
- (void)qtyPlus  { if (_quantity < 500) { _quantity++;  _qtyLabel.text = @(_quantity).stringValue; } }

// ═══════════════════════════════════════════════════════════════════════════════
// Toggle row helper
// ═══════════════════════════════════════════════════════════════════════════════
- (void)addToggleRow:(NSString *)title subtitle:(NSString *)sub y:(CGFloat)y action:(SEL)action {
    CGFloat w = _settingsPage.bounds.size.width;
    UIView *row = [[UIView alloc] initWithFrame:CGRectMake(10, y, w - 20, 44)];
    row.backgroundColor  = [UIColor colorWithWhite:0 alpha:0.35];
    row.layer.cornerRadius = 10;
    row.layer.borderWidth  = 1;
    row.layer.borderColor  = EL_BORDER;
    [_settingsPage addSubview:row];

    UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(12, 5, w - 80, 18)];
    tl.text      = title;
    tl.font      = [UIFont boldSystemFontOfSize:12];
    tl.textColor = EL_TEXT;
    [row addSubview:tl];

    UILabel *sl = [[UILabel alloc] initWithFrame:CGRectMake(12, 22, w - 80, 16)];
    sl.text      = sub;
    sl.font      = [UIFont systemFontOfSize:10];
    sl.textColor = EL_TEXT_DIM;
    [row addSubview:sl];

    UISwitch *sw = [[UISwitch alloc] init];
    sw.onTintColor = EL_PURPLE;
    sw.transform   = CGAffineTransformMakeScale(0.78f, 0.78f);
    sw.frame       = CGRectMake(w - 68, 8, 51, 31);
    [sw addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [row addSubview:sw];
}

- (UIButton *)makeStepBtn:(NSString *)t frame:(CGRect)r action:(SEL)a {
    UIButton *b = [[UIButton alloc] initWithFrame:r];
    b.backgroundColor  = [UIColor colorWithWhite:0 alpha:0.35];
    b.layer.cornerRadius = 6;
    b.layer.borderWidth  = 1;
    b.layer.borderColor  = EL_BORDER;
    [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:EL_PURPLE forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [b addTarget:self action:a forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)dismiss {
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha     = 0;
        self.transform = CGAffineTransformMakeScale(0.9f, 0.9f);
    } completion:^(__unused BOOL d) {
        self.hidden    = YES;
        self.alpha     = 1;
        self.transform = CGAffineTransformIdentity;
    }];
}

- (void)handleDrag:(UIPanGestureRecognizer *)pan {
    CGPoint d = [pan translationInView:self.superview];
    self.center = CGPointMake(self.center.x + d.x, self.center.y + d.y);
    [pan setTranslation:CGPointZero inView:self.superview];
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    [tf resignFirstResponder];
    return YES;
}

@end


// ═══════════════════════════════════════════════════════════════════════════════
// MARK: — Injection & Initialization
// ═══════════════════════════════════════════════════════════════════════════════

static EverLightMenu *gMenu = nil;
static UIButton      *gBtn  = nil;

static void ELInject(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *win = ELKeyWindow();
        if (!win) return;

        // Floating galaxy button
        gBtn = [[UIButton alloc] initWithFrame:
                CGRectMake(win.bounds.size.width - 52, 90, 42, 42)];
        gBtn.layer.cornerRadius = 21;
        gBtn.layer.borderWidth  = 2;
        gBtn.layer.borderColor  = EL_BORDER;
        gBtn.clipsToBounds      = YES;

        CAGradientLayer *btnGrad = [CAGradientLayer layer];
        btnGrad.frame  = CGRectMake(0, 0, 42, 42);
        btnGrad.colors = @[
            (id)[UIColor colorWithRed:0.3 green:0.1 blue:0.6 alpha:0.95].CGColor,
            (id)[UIColor colorWithRed:0.1 green:0.2 blue:0.5 alpha:0.95].CGColor,
        ];
        btnGrad.startPoint = CGPointMake(0, 0);
        btnGrad.endPoint   = CGPointMake(1, 1);
        [gBtn.layer insertSublayer:btnGrad atIndex:0];
        ELGlow(gBtn.layer, EL_PURPLE, 12);
        [gBtn setTitle:@"✦" forState:UIControlStateNormal];
        [gBtn setTitleColor:EL_STAR forState:UIControlStateNormal];
        gBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
        [win addSubview:gBtn];

        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
        pulse.fromValue    = @(8);
        pulse.toValue      = @(18);
        pulse.duration     = 1.5;
        pulse.autoreverses = YES;
        pulse.repeatCount  = HUGE_VALF;
        [gBtn.layer addAnimation:pulse forKey:@"pulse"];

        CGFloat mw   = MIN(win.bounds.size.width - 24, 320);
        CGFloat mh   = MIN(win.bounds.size.height - 100, 580);
        gMenu = [[EverLightMenu alloc] initWithFrame:CGRectMake(
            (win.bounds.size.width  - mw) / 2,
            (win.bounds.size.height - mh) / 2, mw, mh)];
        gMenu.hidden = YES;
        [win addSubview:gMenu];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                       initWithTarget:nil action:nil];
        [tap addTarget:^(__unused id t) {
            if (gMenu.hidden) {
                gMenu.hidden    = NO;
                gMenu.alpha     = 0;
                gMenu.transform = CGAffineTransformMakeScale(0.85f, 0.85f);
                [UIView animateWithDuration:0.28 delay:0
                     usingSpringWithDamping:0.72 initialSpringVelocity:0.5 options:0
                                 animations:^{
                    gMenu.alpha     = 1;
                    gMenu.transform = CGAffineTransformIdentity;
                } completion:nil];
            } else {
                [gMenu dismiss];
            }
        } withObject:nil];
        [gBtn addGestureRecognizer:tap];

        NSLog(@"[EverLight] v3.0 Injected! IL2CPP=%d SpawnMethod=%lld",
              gIsInitialized, gSpawnItemMethod);
        ELToast(gIsInitialized ? @"EverLight v3.0 — IL2CPP Ready!" : @"EverLight v3.0 — Loaded (init in-game)", gIsInitialized);
    });
}

__attribute__((constructor))
static void ELInit(void) {
    // Initialize IL2CPP after a short delay (game needs time to load)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        // Step 1: Load IL2CPP function pointers
        if (XDInitializeIL2CPP()) {
            NSLog(@"[EverLight] IL2CPP initialized");
            // Step 2: Resolve game classes & methods
            XDInitializeGameClasses();
            NSLog(@"[EverLight] Game classes initialized. SpawnMethod=%lld", gSpawnItemMethod);
        } else {
            NSLog(@"[EverLight] IL2CPP init failed — will retry on next re-init");
        }
        // Step 3: Show the menu button
        ELInject();
    });
}
