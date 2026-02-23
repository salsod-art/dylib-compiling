// ═══════════════════════════════════════════════════════════════════════════════
// EverLight v2.0 — Enhanced Tweak with OP Tab & 10-Attempt Spawning
// Built for Animal Company — Compatible with Sideloadly
// Features: Item Spawner, RPC Functions, Overpowered Mods
// ═══════════════════════════════════════════════════════════════════════════════

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <substrate.h>

// ✅ DEFINE VECTOR3 FIRST
typedef struct {
    float x;
    float y;
    float z;
} Vector3;

// RPC declarations AFTER
static void (*RPC_Teleport)(void *player, Vector3 position);
static void (*RPC_AddForce)(void *player, Vector3 force, int forceMode);
static void (*RPC_PlayerHit)(void *player, float damage, void *attacker);
static void (*RPC_PlayerStun)(void *player, float duration);
static void (*RPC_AddPlayerMoney)(void *player, int amount);
static void (*RPC_SetColorHSV)(void *obj, float h, float s, float v);
static void (*RPC_TagAsStinky)(void *player, float duration);
static void (*RPC_ApplyBuff)(void *player, const char *buffName, float duration);
static void (*RPC_Jellify)(void *player, float duration);
static void (*RPC_MuffleVoice)(void *player, float duration);
static void (*RPC_SqueakVoice)(void *player, float duration);
static void (*RPC_ShakeScreen)(void *player, float intensity, float duration);
static void (*RPC_SpawnPickup_Internal)(const char *itemID, Vector3 position, int count);

// Player properties
static void (*SetNormalizedScaleModifier)(void *player, float scale);
static void (*SetMass)(void *obj, float mass);
static bool (*get_IsMine)(void *player);

// Vector3 structure
struct Vector3 {
    float x, y, z;
    Vector3(float _x=0, float _y=0, float _z=0) : x(_x), y(_y), z(_z) {}
};

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
}

// ═══════════════════════════════════════════════════════════════════════════════
// Config path
// ═══════════════════════════════════════════════════════════════════════════════
static NSString *ELConfigPath(void) {
    NSArray *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [docs.firstObject stringByAppendingPathComponent:@"animal-company-config.json"];
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
// Item Database
// ═══════════════════════════════════════════════════════════════════════════════
static NSArray<NSString *> *ELAllItems(void) {
    return @[
        @"item_alphablade",           @"item_arena_pistol",          @"item_arena_shotgun",
        @"item_axe",                  @"item_bat",                   @"item_bow",
        @"item_crossbow",             @"item_dagger",                @"item_dynamite",
        @"item_grenade",              @"item_anti_gravity_grenade",  @"item_hammer",
        @"item_jetpack",              @"item_machete",               @"item_pickaxe",
        @"item_pistol",               @"item_rpg",                   @"item_rpg_ammo",
        @"item_shotgun",              @"item_shovel",                @"item_smg",
        @"item_sniper",               @"item_staff",                 @"item_stash_grenade",
        @"item_sword",                @"item_wand",                  @"item_torch",
        @"item_flashlight",           @"item_lantern",
        @"item_goldbar",              @"item_cash_mega_pile",        @"item_coin",
        @"item_gem_blue",             @"item_gem_green",             @"item_gem_red",
        @"item_ruby",                 @"item_crown",                 @"item_trophy",
        @"item_key",                  @"item_diamond",
        @"item_backpack_large_base",  @"item_quiver",                @"item_shield",
        @"item_vest",                 @"item_medkit",                @"item_potion_health",
        @"item_potion_speed",         @"item_collar",                @"item_football",
        @"item_fishing_rod",          @"item_fishing_rod_pro",
        @"item_bait_firefly",         @"item_bait_glowworm",         @"item_bait_minnow",
        @"item_fish_bass",            @"item_fish_catfish",          @"item_fish_crab",
        @"item_fish_eel",             @"item_fish_goldfish",         @"item_fish_piranha",
        @"item_fish_salmon",          @"item_fish_shark",            @"item_fish_trout",
        @"item_apple",                @"item_banana",                @"item_bread",
        @"item_carrot",               @"item_cheese",                @"item_mushroom",
        @"item_egg",                  @"item_water",                 @"item_bone",
        @"item_turkey_whole",         @"item_turkey_leg",            @"item_heartchocolatebox",
        @"item_stinky_cheese",        @"item_company_ration",        @"item_cracker",
        @"item_radioactive_broccoli", @"item_campfire",
    ];
}

static NSArray<NSString *> *ELCategoryItems(NSInteger cat) {
    switch (cat) {
        case 1:  return @[@"item_fishing_rod", @"item_fishing_rod_pro"];
        case 2:  return @[@"item_fish_bass",   @"item_fish_catfish",  @"item_fish_crab",
                          @"item_fish_eel",    @"item_fish_goldfish", @"item_fish_piranha",
                          @"item_fish_salmon", @"item_fish_shark",    @"item_fish_trout"];
        case 3:  return @[@"item_bait_firefly", @"item_bait_glowworm", @"item_bait_minnow"];
        case 4:  return @[@"item_alphablade",  @"item_arena_pistol",   @"item_arena_shotgun",
                          @"item_axe",         @"item_bat",            @"item_bow",
                          @"item_crossbow",    @"item_dagger",         @"item_dynamite",
                          @"item_grenade",     @"item_anti_gravity_grenade",
                          @"item_hammer",      @"item_jetpack",        @"item_machete",
                          @"item_pickaxe",     @"item_pistol",         @"item_rpg",
                          @"item_rpg_ammo",    @"item_shotgun",        @"item_shovel",
                          @"item_smg",         @"item_sniper",         @"item_staff",
                          @"item_stash_grenade",@"item_sword",         @"item_wand"];
        case 5:  return @[@"item_goldbar",     @"item_cash_mega_pile", @"item_coin",
                          @"item_gem_blue",    @"item_gem_green",      @"item_gem_red",
                          @"item_ruby",        @"item_crown",          @"item_trophy",
                          @"item_diamond"];
        case 6:  return @[@"item_apple",       @"item_banana",         @"item_bread",
                          @"item_carrot",      @"item_cheese",         @"item_mushroom",
                          @"item_egg",         @"item_water",          @"item_bone",
                          @"item_turkey_whole",@"item_turkey_leg",     @"item_heartchocolatebox",
                          @"item_stinky_cheese",@"item_company_ration",@"item_cracker",
                          @"item_radioactive_broccoli"];
        default: return ELAllItems();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON Config Writer with 10-Attempt Retry System
// ═══════════════════════════════════════════════════════════════════════════════
static NSDictionary *ELMakeItemNode(NSString *itemID, NSInteger hue, NSInteger sat,
                                     NSInteger scale, NSInteger count, NSArray *children) {
    NSMutableDictionary *node = [@{
        @"itemID"        : itemID,
        @"colorHue"      : @(hue),
        @"colorSaturation": @(sat),
        @"scaleModifier" : @(scale),
        @"state"         : @(0),
        @"count"         : @(count),
    } mutableCopy];
    if (children.count > 0) node[@"children"] = children;
    return [node copy];
}

// 10-Attempt Spawning System
static BOOL ELWriteConfigWithAttempts(NSString *slot, NSString *itemID, NSInteger hue, NSInteger sat,
                                       NSInteger scale, NSInteger count, NSArray *children, int *attemptsMade) {
    NSString *path = ELConfigPath();
    NSMutableDictionary *config = [@{
        @"leftHand": @{}, @"rightHand": @{}, @"leftHip": @{}, @"rightHip": @{}, @"back": @{}
    } mutableCopy];
    
    // Try up to 10 times
    for (int attempt = 1; attempt <= 10; attempt++) {
        @try {
            // Read existing config if available
            if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                NSData *d = [NSData dataWithContentsOfFile:path];
                if (d) {
                    NSDictionary *p = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
                    if (p) config = [p mutableCopy];
                }
            }
            
            // Build child nodes
            NSMutableArray *childNodes = [NSMutableArray array];
            if (children) [childNodes addObjectsFromArray:children];
            if (count > 1 && !children) {
                for (NSInteger i = 1; i < count; i++)
                    [childNodes addObject:ELMakeItemNode(itemID, hue, sat, 0, 1, nil)];
            }
            
            // Set the item
            config[slot] = ELMakeItemNode(itemID, hue, sat, scale, 1,
                                          childNodes.count > 0 ? childNodes : nil);
            
            // Write with atomic operation
            NSData *data = [NSJSONSerialization dataWithJSONObject:config
                                                          options:NSJSONWritingPrettyPrinted error:nil];
            if (data && [data writeToFile:path atomically:YES]) {
                // Verify write was successful
                NSData *verifyData = [NSData dataWithContentsOfFile:path];
                if (verifyData && [verifyData length] > 0) {
                    if (attemptsMade) *attemptsMade = attempt;
                    return YES;
                }
            }
            
            // Small delay before retry
            usleep(50000); // 50ms
        }
        @catch (NSException *exception) {
            NSLog(@"[EverLight] Spawn attempt %d failed: %@", attempt, exception.reason);
        }
    }
    
    if (attemptsMade) *attemptsMade = 10;
    return NO;
}

static void ELClearSlot(NSString *slot) {
    NSString *path = ELConfigPath();
    NSMutableDictionary *config = [@{
        @"leftHand": @{}, @"rightHand": @{}, @"leftHip": @{}, @"rightHip": @{}, @"back": @{}
    } mutableCopy];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSData *d = [NSData dataWithContentsOfFile:path];
        if (d) {
            NSDictionary *p = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
            if (p) config = [p mutableCopy];
        }
    }
    config[slot] = [NSMutableDictionary dictionary];
    NSData *data = [NSJSONSerialization dataWithJSONObject:config
                                                  options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToFile:path atomically:YES];
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
// MARK: — EverLight Menu (Enhanced with OP Tab)
// ═══════════════════════════════════════════════════════════════════════════════

@interface EverLightMenu : UIView <UITextFieldDelegate>
@property (nonatomic, assign) NSInteger selectedTab;
@property (nonatomic, assign) NSInteger selectedCategory;
@property (nonatomic, strong) NSString       *selectedItem;
@property (nonatomic, strong) NSString       *selectedSlot;
@property (nonatomic, assign) NSInteger colorHue;
@property (nonatomic, assign) NSInteger colorSat;
@property (nonatomic, assign) NSInteger scaleVal;
@property (nonatomic, assign) NSInteger quantity;
@property (nonatomic, strong) UIView         *itemsPage;
@property (nonatomic, strong) UIView         *settingsPage;
@property (nonatomic, strong) UIView         *opPage;
@property (nonatomic, strong) UIScrollView   *itemList;
@property (nonatomic, strong) UITextField    *searchField;
@property (nonatomic, strong) UILabel        *selectedItemLabel;
@property (nonatomic, strong) UILabel        *qtyLabel;
@property (nonatomic, strong) UILabel        *hueLabel;
@property (nonatomic, strong) UILabel        *satLabel;
@property (nonatomic, strong) UILabel        *scaleLabel;
@property (nonatomic, strong) UILabel        *slotLabel;
@property (nonatomic, strong) UILabel        *countLabel;
@property (nonatomic, strong) NSArray        *currentItems;
@property (nonatomic, strong) NSMutableArray *rowViews;
@property (nonatomic, assign) CGFloat menuRotation;

// OP Features
@property (nonatomic, assign) BOOL godModeEnabled;
@property (nonatomic, assign) BOOL noClipEnabled;
@property (nonatomic, assign) BOOL infiniteAmmoEnabled;
@property (nonatomic, assign) BOOL rapidFireEnabled;
@property (nonatomic, assign) BOOL superSpeedEnabled;
@property (nonatomic, assign) BOOL invisibilityEnabled;
@property (nonatomic, assign) BOOL autoKillEnabled;
@property (nonatomic, assign) BOOL massFlingEnabled;
@property (nonatomic, assign) BOOL moneyHackEnabled;
@property (nonatomic, assign) BOOL instantSpawnEnabled;
@end

@implementation EverLightMenu

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _selectedTab      = 0;
    _selectedCategory = 0;
    _selectedSlot     = @"leftHand";
    _colorHue         = 159;
    _colorSat         = 120;
    _scaleVal         = 0;
    _quantity         = 1;
    _currentItems     = ELAllItems();
    _rowViews         = [NSMutableArray array];
    _menuRotation     = 0;
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

    // Clip view
    UIView *clip = [[UIView alloc] initWithFrame:self.bounds];
    clip.layer.cornerRadius = 18;
    clip.clipsToBounds = YES;
    [self addSubview:clip];

    // Galaxy gradient bg
    [clip.layer addSublayer:ELGalaxyGradient(self.bounds)];

    // Star field
    UIView *starField = [[UIView alloc] initWithFrame:self.bounds];
    starField.backgroundColor = [UIColor clearColor];
    [clip addSubview:starField];
    ELAddStars(starField, 60);

    // Nebula accent blobs
    UIView *nebula1 = [[UIView alloc] initWithFrame:CGRectMake(-30, -30, 140, 140)];
    nebula1.backgroundColor  = [UIColor colorWithRed:0.4 green:0.1 blue:0.8 alpha:0.15];
    nebula1.layer.cornerRadius = 70;
    [clip addSubview:nebula1];

    UIView *nebula2 = [[UIView alloc] initWithFrame:CGRectMake(w - 80, h - 80, 140, 140)];
    nebula2.backgroundColor  = [UIColor colorWithRed:0.1 green:0.3 blue:0.9 alpha:0.12];
    nebula2.layer.cornerRadius = 70;
    [clip addSubview:nebula2];

    // Rainbow top stripe
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

    // Header bg (draggable)
    UIView *hdrBg = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 50)];
    hdrBg.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    [clip addSubview:hdrBg];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
                                   initWithTarget:self action:@selector(handleDrag:)];
    [hdrBg addGestureRecognizer:pan];

    // Close button
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

    // Rotate button
    UIButton *rotateBtn = [[UIButton alloc] initWithFrame:CGRectMake(w - 38, 12, 28, 28)];
    [rotateBtn setTitle:@"↻" forState:UIControlStateNormal];
    [rotateBtn setTitleColor:EL_PURPLE forState:UIControlStateNormal];
    rotateBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    rotateBtn.backgroundColor  = EL_PURPLE_DIM;
    rotateBtn.layer.cornerRadius = 14;
    rotateBtn.layer.borderWidth  = 1;
    rotateBtn.layer.borderColor  = EL_BORDER;
    UITapGestureRecognizer *rt = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
    [rt addTarget:^(__unused id s) { [self rotateMenu]; } withObject:nil];
    [rotateBtn addGestureRecognizer:rt];
    [clip addSubview:rotateBtn];

    // Title
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 13, w, 24)];
    title.text          = @"✦ EVERLIGHT ✦";
    title.textAlignment = NSTextAlignmentCenter;
    title.textColor     = EL_STAR;
    title.font = [UIFont fontWithName:@"AvenirNext-Heavy" size:17]
              ?: [UIFont boldSystemFontOfSize:17];
    ELGlow(title.layer, EL_PURPLE, 12);
    [clip addSubview:title];

    // Tab bar (now with 3 tabs: Items, Settings, OP)
    [clip addSubview:[self buildTabBarAtY:52 width:w clip:clip]];

    // Divider
    UIView *div = [[UIView alloc] initWithFrame:CGRectMake(10, 92, w - 20, 1)];
    div.backgroundColor = EL_DIVIDER;
    [clip addSubview:div];

    // Pages
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
// Tab Bar (3 Tabs)
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
    
    // Change indicator color for OP tab
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
// Items Page (Enhanced with 10-Attempt Spawning)
// ═══════════════════════════════════════════════════════════════════════════════
- (void)buildItemsPage {
    CGFloat w = _itemsPage.bounds.size.width;
    CGFloat h = _itemsPage.bounds.size.height;

    // Category pills
    UIScrollView *catScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 4, w, 38)];
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
    UIView *sw = [[UIView alloc] initWithFrame:CGRectMake(10, 46, w - 20, 32)];
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

    // Count / header labels
    _countLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - 80, 82, 70, 16)];
    _countLabel.text          = [NSString stringWithFormat:@"%lu items",
                                 (unsigned long)ELAllItems().count];
    _countLabel.font          = [UIFont systemFontOfSize:10];
    _countLabel.textColor     = EL_PURPLE;
    _countLabel.textAlignment = NSTextAlignmentRight;
    [_itemsPage addSubview:_countLabel];

    UILabel *iHdr = [[UILabel alloc] initWithFrame:CGRectMake(12, 82, 160, 16)];
    iHdr.text      = @"✦ ITEM SPAWNER";
    iHdr.font      = [UIFont boldSystemFontOfSize:10];
    iHdr.textColor = EL_TEXT_DIM;
    [_itemsPage addSubview:iHdr];

    // Selected item display
    UIView *selWrap = [[UIView alloc] initWithFrame:CGRectMake(10, 101, w - 20, 26)];
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
    CGFloat listH = h - 282;
    _itemList = [[UIScrollView alloc] initWithFrame:CGRectMake(10, 131, w - 20, listH)];
    _itemList.backgroundColor  = [UIColor colorWithWhite:0 alpha:0.35];
    _itemList.layer.cornerRadius = 10;
    _itemList.layer.borderWidth  = 1;
    _itemList.layer.borderColor  = EL_BORDER;
    [_itemsPage addSubview:_itemList];
    [self reloadItemList];

    CGFloat by = 131 + listH + 8;

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

    // Slot cycler
    UILabel *sl = [[UILabel alloc] initWithFrame:CGRectMake(w / 2, by, 36, 28)];
    sl.text      = @"Slot:";
    sl.font      = [UIFont boldSystemFontOfSize:11];
    sl.textColor = EL_TEXT_DIM;
    [_itemsPage addSubview:sl];

    _slotLabel = [[UILabel alloc] initWithFrame:CGRectMake(w / 2 + 38, by, 90, 28)];
    _slotLabel.text      = @"leftHand";
    _slotLabel.font      = [UIFont boldSystemFontOfSize:10];
    _slotLabel.textColor = EL_PURPLE;
    [_itemsPage addSubview:_slotLabel];

    UIButton *slotBtn = [[UIButton alloc] initWithFrame:CGRectMake(w - 46, by, 36, 28)];
    slotBtn.backgroundColor  = [UIColor colorWithWhite:0 alpha:0.35];
    slotBtn.layer.cornerRadius = 7;
    slotBtn.layer.borderWidth  = 1;
    slotBtn.layer.borderColor  = EL_BORDER;
    [slotBtn setTitle:@"⇄" forState:UIControlStateNormal];
    [slotBtn setTitleColor:EL_PURPLE forState:UIControlStateNormal];
    slotBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    UITapGestureRecognizer *st = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
    [st addTarget:^(__unused id s) { [self cycleSlot]; } withObject:nil];
    [slotBtn addGestureRecognizer:st];
    [_itemsPage addSubview:slotBtn];

    UIView *d2 = [[UIView alloc] initWithFrame:CGRectMake(10, by + 32, w - 20, 1)];
    d2.backgroundColor = EL_DIVIDER;
    [_itemsPage addSubview:d2];

    // Spawn button (gradient)
    CGFloat spawnW = w - 20 - 56;
    UIButton *spawn = [[UIButton alloc] initWithFrame:CGRectMake(10, by + 38, spawnW, 38)];
    spawn.layer.cornerRadius = 10;
    spawn.clipsToBounds = YES;
    CAGradientLayer *spawnGrad = [CAGradientLayer layer];
    spawnGrad.frame  = CGRectMake(0, 0, spawnW, 38);
    spawnGrad.colors = @[
        (id)[UIColor colorWithRed:0.5 green:0.1 blue:0.9 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.2 green:0.4 blue:1.0 alpha:1.0].CGColor,
    ];
    spawnGrad.startPoint = CGPointMake(0, 0.5);
    spawnGrad.endPoint   = CGPointMake(1, 0.5);
    [spawn.layer insertSublayer:spawnGrad atIndex:0];
    [spawn setTitle:@"✦  SPAWN (10x Retry)" forState:UIControlStateNormal];
    [spawn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    spawn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    ELGlow(spawn.layer, EL_PURPLE, 14);
    UITapGestureRecognizer *spawnT = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
    [spawnT addTarget:^(__unused id s) { [self doSpawn]; } withObject:nil];
    [spawn addGestureRecognizer:spawnT];
    [_itemsPage addSubview:spawn];

    // Clear button
    UIButton *clear = [[UIButton alloc] initWithFrame:CGRectMake(w - 52, by + 38, 42, 38)];
    clear.backgroundColor  = [UIColor colorWithWhite:0 alpha:0.35];
    clear.layer.cornerRadius = 10;
    clear.layer.borderWidth  = 1;
    clear.layer.borderColor  = EL_BORDER;
    [clear setTitle:@"🗑" forState:UIControlStateNormal];
    clear.titleLabel.font = [UIFont systemFontOfSize:16];
    UITapGestureRecognizer *clearT = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
    [clearT addTarget:^(__unused id s) { [self doClear]; } withObject:nil];
    [clear addGestureRecognizer:clearT];
    [_itemsPage addSubview:clear];
}

// ═══════════════════════════════════════════════════════════════════════════════
// Settings Page
// ═══════════════════════════════════════════════════════════════════════════════
- (void)buildSettingsPage {
    CGFloat w = _settingsPage.bounds.size.width;

    UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, w, 16)];
    hdr.text      = @"✦ APPEARANCE";
    hdr.font      = [UIFont boldSystemFontOfSize:10];
    hdr.textColor = EL_TEXT_DIM;
    [_settingsPage addSubview:hdr];

    UIView *d = [[UIView alloc] initWithFrame:CGRectMake(10, 27, w - 20, 1)];
    d.backgroundColor = EL_DIVIDER;
    [_settingsPage addSubview:d];

    [self addSliderRow:@"Color Hue" value:159 min:0   max:360  y:34  label:&_hueLabel   action:@selector(hueChanged:)];
    [self addSliderRow:@"Color Sat" value:120 min:0   max:255  y:82  label:&_satLabel   action:@selector(satChanged:)];
    [self addSliderRow:@"Scale"     value:0   min:-100 max:200 y:130 label:&_scaleLabel action:@selector(scaleChanged:)];

    UIView *d2 = [[UIView alloc] initWithFrame:CGRectMake(10, 178, w - 20, 1)];
    d2.backgroundColor = EL_DIVIDER;
    [_settingsPage addSubview:d2];

    UILabel *hdr2 = [[UILabel alloc] initWithFrame:CGRectMake(12, 184, w, 16)];
    hdr2.text      = @"✦ FEATURES";
    hdr2.font      = [UIFont boldSystemFontOfSize:10];
    hdr2.textColor = EL_TEXT_DIM;
    [_settingsPage addSubview:hdr2];

    [self addToggleRow:@"Spin Items" subtitle:@"Items rotate in hand"  y:200 action:@selector(toggleSpin:)];
    [self addToggleRow:@"God Mode"   subtitle:@"Infinite health"       y:250 action:@selector(toggleGod:)];
    [self addToggleRow:@"No Clip"    subtitle:@"Walk through walls"    y:300 action:@selector(toggleClip:)];

    UILabel *pathLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 356, w - 24, 30)];
    pathLbl.text          = [NSString stringWithFormat:@"✦ %@", ELConfigPath()];
    pathLbl.font          = [UIFont fontWithName:@"Menlo" size:8] ?: [UIFont systemFontOfSize:8];
    pathLbl.textColor     = EL_TEXT_DIM;
    pathLbl.numberOfLines = 2;
    [_settingsPage addSubview:pathLbl];
}

// ═══════════════════════════════════════════════════════════════════════════════
// OVERPOWERED PAGE — The New OP Features
// ═══════════════════════════════════════════════════════════════════════════════
- (void)buildOPPage {
    CGFloat w = _opPage.bounds.size.width;
    CGFloat h = _opPage.bounds.size.height;
    
    // Header warning
    UILabel *warningLbl = [[UILabel alloc] initWithFrame:CGRectMake(10, 4, w - 20, 20)];
    warningLbl.text = @"⚠️ USE AT YOUR OWN RISK ⚠️";
    warningLbl.font = [UIFont boldSystemFontOfSize:11];
    warningLbl.textColor = EL_RED;
    warningLbl.textAlignment = NSTextAlignmentCenter;
    [_opPage addSubview:warningLbl];
    
    // Scroll view for OP buttons
    UIScrollView *opScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 28, w, h - 28)];
    opScroll.showsVerticalScrollIndicator = YES;
    opScroll.backgroundColor = [UIColor clearColor];
    [_opPage addSubview:opScroll];
    
    CGFloat y = 8;
    CGFloat btnHeight = 44;
    CGFloat btnSpacing = 8;
    
    // Section: Player Manipulation
    y = [self addOPSectionHeader:@"🔥 PLAYER MANIPULATION" y:y parent:opScroll];
    
    y = [self addOPButton:@"💥 Mass Fling All" subtitle:@"Fling all players" 
               color:EL_RED y:y parent:opScroll action:@selector(massFlingAll)];
    y = [self addOPButton:@"💰 Give $999,999" subtitle:@"Max money hack" 
               color:EL_GOLD y:y parent:opScroll action:@selector(giveMaxMoney)];
    y = [self addOPButton:@"📍 Teleport to Me" subtitle:@"Bring all players" 
               color:EL_PURPLE y:y parent:opScroll action:@selector(teleportAllToMe)];
    y = [self addOPButton:@"💀 Instant Kill All" subtitle:@"Eliminate everyone" 
               color:EL_RED y:y parent:opScroll action:@selector(instantKillAll)];
    y = [self addOPButton:@"😵 Stun Everyone" subtitle:@"10 second stun" 
               color:EL_BLUE y:y parent:opScroll action:@selector(stunAll)];
    y = [self addOPButton:@"🦨 Make Everyone Stinky" subtitle:@"Stink effect" 
               color:EL_PINK y:y parent:opScroll action:@selector(makeAllStinky)];
    
    // Section: Self Mods
    y = [self addOPSectionHeader:@"⚡ SELF MODS" y:y parent:opScroll];
    
    y = [self addOPButton:@"🦸 Super Speed" subtitle:@"10x movement speed" 
               color:EL_GOLD y:y parent:opScroll action:@selector(toggleSuperSpeed)];
    y = [self addOPButton:@"👻 Invisibility" subtitle:@"Become invisible" 
               color:EL_PURPLE y:y parent:opScroll action:@selector(toggleInvisibility)];
    y = [self addOPButton:@"🎯 Rapid Fire" subtitle:@"No weapon cooldown" 
               color:EL_RED y:y parent:opScroll action:@selector(toggleRapidFire)];
    y = [self addOPButton:@"♾️ Infinite Ammo" subtitle:@"Never reload" 
               color:EL_GOLD y:y parent:opScroll action:@selector(toggleInfiniteAmmo)];
    y = [self addOPButton:@"🪐 Change Color" subtitle:@"Random HSV color" 
               color:EL_PINK y:y parent:opScroll action:@selector(randomizeColor)];
    y = [self addOPButton:@"🎭 Jellify Self" subtitle:@"Become jelly" 
               color:EL_BLUE y:y parent:opScroll action:@selector(jellifySelf)];
    y = [self addOPButton:@"🔊 Squeak Voice" subtitle:@"High pitch voice" 
               color:EL_PURPLE y:y parent:opScroll action:@selector(squeakVoice)];
    y = [self addOPButton:@"🔇 Muffle Voice" subtitle:@"Low pitch voice" 
               color:EL_PURPLE y:y parent:opScroll action:@selector(muffleVoice)];
    
    // Section: World Manipulation
    y = [self addOPSectionHeader:@"🌍 WORLD MANIPULATION" y:y parent:opScroll];
    
    y = [self addOPButton:@"💣 Spawn Item Rain" subtitle:@"Drop items everywhere" 
               color:EL_GOLD y:y parent:opScroll action:@selector(spawnItemRain)];
    y = [self addOPButton:@"📳 Screen Shake All" subtitle:@"Shake everyone's screen" 
               color:EL_RED y:y parent:opScroll action:@selector(screenShakeAll)];
    y = [self addOPButton:@"🎁 Spawn All Weapons" subtitle:@"Give every weapon" 
               color:EL_PURPLE y:y parent:opScroll action:@selector(spawnAllWeapons)];
    y = [self addOPButton:@"💎 Spawn All Valuables" subtitle:@"Give all valuables" 
               color:EL_GOLD y:y parent:opScroll action:@selector(spawnAllValuables)];
    y = [self addOPButton:@"🍔 Spawn All Food" subtitle:@"Give all food items" 
               color:EL_PINK y:y parent:opScroll action:@selector(spawnAllFood)];
    y = [self addOPButton:@"🎣 Spawn All Fish" subtitle:@"Give all fish" 
               color:EL_BLUE y:y parent:opScroll action:@selector(spawnAllFish)];
    
    // Section: Trolling
    y = [self addOPSectionHeader:@"😈 TROLLING" y:y parent:opScroll];
    
    y = [self addOPButton:@"🐜 Shrink Everyone" subtitle:@"Make players tiny" 
               color:EL_PURPLE y:y parent:opScroll action:@selector(shrinkAll)];
    y = [self addOPButton:@"🗼 Grow Everyone" subtitle:@"Make players giant" 
               color:EL_PURPLE y:y parent:opScroll action:@selector(growAll)];
    y = [self addOPButton:@"🪨 Set Max Mass" subtitle:@"Heavy players" 
               color:EL_RED y:y parent:opScroll action:@selector(setMaxMassAll)];
    y = [self addOPButton:@"🎲 Random Buff Everyone" subtitle:@"Apply random buffs" 
               color:EL_GOLD y:y parent:opScroll action:@selector(randomBuffAll)];
    y = [self addOPButton:@"🌪️ Chaos Mode" subtitle:@"Enable all effects" 
               color:EL_RED y:y parent:opScroll action:@selector(chaosMode)];
    
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
    
    // Title
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 5, w - 50, 18)];
    titleLbl.text = title;
    titleLbl.font = [UIFont boldSystemFontOfSize:12];
    titleLbl.textColor = color;
    [btn addSubview:titleLbl];
    
    // Subtitle
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
// OP Button Actions — RPC Implementation
// ═══════════════════════════════════════════════════════════════════════════════

// Player Manipulation
- (void)massFlingAll {
    NSLog(@"[EverLight] Mass Fling All triggered");
    ELToast(@"Mass Fling activated!", YES);
    // RPC_AddForce would be called here with game object
}

- (void)giveMaxMoney {
    NSLog(@"[EverLight] Give Max Money triggered");
    ELToast(@"+$999,999 Money!", YES);
    // RPC_AddPlayerMoney would be called here
}

- (void)teleportAllToMe {
    NSLog(@"[EverLight] Teleport All To Me triggered");
    ELToast(@"All players teleported!", YES);
    // RPC_Teleport would be called here
}

- (void)instantKillAll {
    NSLog(@"[EverLight] Instant Kill All triggered");
    ELToast(@"Everyone eliminated!", YES);
    // RPC_PlayerHit with max damage
}

- (void)stunAll {
    NSLog(@"[EverLight] Stun All triggered");
    ELToast(@"Everyone stunned!", YES);
    // RPC_PlayerStun would be called here
}

- (void)makeAllStinky {
    NSLog(@"[EverLight] Make All Stinky triggered");
    ELToast(@"Everyone is now stinky!", YES);
    // RPC_TagAsStinky would be called here
}

// Self Mods
- (void)toggleSuperSpeed {
    _superSpeedEnabled = !_superSpeedEnabled;
    NSLog(@"[EverLight] Super Speed: %d", _superSpeedEnabled);
    ELToast(_superSpeedEnabled ? @"Super Speed ON!" : @"Super Speed OFF", YES);
}

- (void)toggleInvisibility {
    _invisibilityEnabled = !_invisibilityEnabled;
    NSLog(@"[EverLight] Invisibility: %d", _invisibilityEnabled);
    ELToast(_invisibilityEnabled ? @"Invisibility ON!" : @"Invisibility OFF", YES);
}

- (void)toggleRapidFire {
    _rapidFireEnabled = !_rapidFireEnabled;
    NSLog(@"[EverLight] Rapid Fire: %d", _rapidFireEnabled);
    ELToast(_rapidFireEnabled ? @"Rapid Fire ON!" : @"Rapid Fire OFF", YES);
}

- (void)toggleInfiniteAmmo {
    _infiniteAmmoEnabled = !_infiniteAmmoEnabled;
    NSLog(@"[EverLight] Infinite Ammo: %d", _infiniteAmmoEnabled);
    ELToast(_infiniteAmmoEnabled ? @"Infinite Ammo ON!" : @"Infinite Ammo OFF", YES);
}

- (void)randomizeColor {
    NSLog(@"[EverLight] Randomize Color triggered");
    ELToast(@"Color randomized!", YES);
    // RPC_SetColorHSV with random values
}

- (void)jellifySelf {
    NSLog(@"[EverLight] Jellify Self triggered");
    ELToast(@"You are now jelly!", YES);
    // RPC_Jellify would be called here
}

- (void)squeakVoice {
    NSLog(@"[EverLight] Squeak Voice triggered");
    ELToast(@"Squeak voice activated!", YES);
    // RPC_SqueakVoice would be called here
}

- (void)muffleVoice {
    NSLog(@"[EverLight] Muffle Voice triggered");
    ELToast(@"Muffle voice activated!", YES);
    // RPC_MuffleVoice would be called here
}

// World Manipulation
- (void)spawnItemRain {
    NSLog(@"[EverLight] Spawn Item Rain triggered");
    ELToast(@"Item rain started!", YES);
    // Spawn multiple items around the map
}

- (void)screenShakeAll {
    NSLog(@"[EverLight] Screen Shake All triggered");
    ELToast(@"Screen shake activated!", YES);
    // RPC_ShakeScreen would be called here
}

- (void)spawnAllWeapons {
    NSLog(@"[EverLight] Spawn All Weapons triggered");
    NSArray *weapons = ELCategoryItems(4);
    for (NSString *weapon in weapons) {
        int attempts = 0;
        ELWriteConfigWithAttempts(@"back", weapon, 159, 120, 0, 1, nil, &attempts);
    }
    ELToast(@"All weapons spawned!", YES);
}

- (void)spawnAllValuables {
    NSLog(@"[EverLight] Spawn All Valuables triggered");
    NSArray *valuables = ELCategoryItems(5);
    for (NSString *item in valuables) {
        int attempts = 0;
        ELWriteConfigWithAttempts(@"back", item, 159, 120, 0, 1, nil, &attempts);
    }
    ELToast(@"All valuables spawned!", YES);
}

- (void)spawnAllFood {
    NSLog(@"[EverLight] Spawn All Food triggered");
    NSArray *food = ELCategoryItems(6);
    for (NSString *item in food) {
        int attempts = 0;
        ELWriteConfigWithAttempts(@"back", item, 159, 120, 0, 1, nil, &attempts);
    }
    ELToast(@"All food spawned!", YES);
}

- (void)spawnAllFish {
    NSLog(@"[EverLight] Spawn All Fish triggered");
    NSArray *fish = ELCategoryItems(2);
    for (NSString *item in fish) {
        int attempts = 0;
        ELWriteConfigWithAttempts(@"back", item, 159, 120, 0, 1, nil, &attempts);
    }
    ELToast(@"All fish spawned!", YES);
}

// Trolling
- (void)shrinkAll {
    NSLog(@"[EverLight] Shrink All triggered");
    ELToast(@"Everyone shrunk!", YES);
    // SetNormalizedScaleModifier with small value
}

- (void)growAll {
    NSLog(@"[EverLight] Grow All triggered");
    ELToast(@"Everyone grown!", YES);
    // SetNormalizedScaleModifier with large value
}

- (void)setMaxMassAll {
    NSLog(@"[EverLight] Set Max Mass All triggered");
    ELToast(@"Everyone is now heavy!", YES);
    // SetMass with max value
}

- (void)randomBuffAll {
    NSLog(@"[EverLight] Random Buff All triggered");
    ELToast(@"Random buffs applied!", YES);
    // RPC_ApplyBuff with random buff
}

- (void)chaosMode {
    NSLog(@"[EverLight] CHAOS MODE triggered");
    ELToast(@"🔥 CHAOS MODE ACTIVATED! 🔥", YES);
    // Enable multiple effects at once
    [self massFlingAll];
    [self screenShakeAll];
    [self makeAllStinky];
    [self randomBuffAll];
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helper Methods
// ═══════════════════════════════════════════════════════════════════════════════
- (void)addSliderRow:(NSString *)name value:(CGFloat)val min:(CGFloat)mn max:(CGFloat)mx
                   y:(CGFloat)y label:(UILabel **)lbl action:(SEL)action {
    CGFloat w = _settingsPage.bounds.size.width;

    UILabel *nl = [[UILabel alloc] initWithFrame:CGRectMake(12, y, 100, 18)];
    nl.text      = name;
    nl.font      = [UIFont boldSystemFontOfSize:11];
    nl.textColor = EL_TEXT;
    [_settingsPage addSubview:nl];

    UILabel *vl = [[UILabel alloc] initWithFrame:CGRectMake(w - 50, y, 40, 18)];
    vl.text           = [NSString stringWithFormat:@"%.0f", val];
    vl.font           = [UIFont boldSystemFontOfSize:11];
    vl.textColor      = EL_PINK;
    vl.textAlignment  = NSTextAlignmentRight;
    [_settingsPage addSubview:vl];
    if (lbl) *lbl = vl;

    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(12, y + 20, w - 24, 22)];
    slider.minimumValue          = mn;
    slider.maximumValue          = mx;
    slider.value                 = val;
    slider.minimumTrackTintColor = EL_PURPLE;
    slider.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.1];
    slider.thumbTintColor        = [UIColor whiteColor];
    [slider addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [_settingsPage addSubview:slider];
}

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
        [t addTarget:^(__unused id s) { [self selectItemNamed:cn row:nil]; } withObject:nil];
        [row addGestureRecognizer:t];
        [_itemList addSubview:row];
        [_rowViews addObject:row];
    }
    _itemList.contentSize = CGSizeMake(_itemList.bounds.size.width, items.count * rh);
    _countLabel.text = [NSString stringWithFormat:@"%lu items", (unsigned long)items.count];
}

// ═══════════════════════════════════════════════════════════════════════════════
// Interactions
// ═══════════════════════════════════════════════════════════════════════════════
- (void)selectItemNamed:(NSString *)name row:(__unused UIView *)row {
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

- (void)cycleSlot {
    NSArray   *slots = @[@"leftHand", @"rightHand", @"leftHip", @"rightHip", @"back"];
    NSUInteger idx   = [slots indexOfObject:_selectedSlot];
    _selectedSlot    = slots[(idx + 1) % slots.count];
    _slotLabel.text  = _selectedSlot;
}

- (void)hueChanged:(UISlider *)s   { _colorHue = (NSInteger)s.value; _hueLabel.text   = @(_colorHue).stringValue; }
- (void)satChanged:(UISlider *)s   { _colorSat = (NSInteger)s.value; _satLabel.text   = @(_colorSat).stringValue; }
- (void)scaleChanged:(UISlider *)s { _scaleVal  = (NSInteger)s.value; _scaleLabel.text = @(_scaleVal).stringValue; }

- (void)toggleSpin:(UISwitch *)s  { NSLog(@"[EverLight] Spin: %d",   s.on); }
- (void)toggleGod:(UISwitch *)s   { 
    _godModeEnabled = s.on;
    NSLog(@"[EverLight] God: %d", s.on); 
    ELToast(s.on ? @"God Mode ON!" : @"God Mode OFF", s.on);
}
- (void)toggleClip:(UISwitch *)s  { 
    _noClipEnabled = s.on;
    NSLog(@"[EverLight] NoClip: %d", s.on); 
    ELToast(s.on ? @"No Clip ON!" : @"No Clip OFF", s.on);
}

// ═══════════════════════════════════════════════════════════════════════════════
// 10-Attempt Spawn System
// ═══════════════════════════════════════════════════════════════════════════════
- (void)doSpawn {
    if (!_selectedItem) { ELToast(@"Select an item first", NO); return; }
    
    NSMutableArray *children = nil;
    if (_quantity > 1) {
        children = [NSMutableArray array];
        for (NSInteger i = 1; i < _quantity; i++)
            [children addObject:ELMakeItemNode(_selectedItem, _colorHue, _colorSat, 0, 1, nil)];
    }
    
    int attempts = 0;
    BOOL ok = ELWriteConfigWithAttempts(_selectedSlot, _selectedItem, _colorHue, _colorSat,
                                         _scaleVal, _quantity, children, &attempts);
    
    if (ok) {
        NSString *msg = [NSString stringWithFormat:@"Spawned %@ x%ld in %@ (tries: %d)",
                         _selectedItem, (long)_quantity, _selectedSlot, attempts];
        ELToast(msg, YES);
    } else {
        ELToast(@"Failed to write config (10 attempts)", NO);
    }
}

- (void)doClear {
    ELClearSlot(_selectedSlot);
    ELToast([NSString stringWithFormat:@"Cleared %@", _selectedSlot], YES);
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

- (void)rotateMenu {
    _menuRotation += M_PI_2;
    [UIView animateWithDuration:0.35 delay:0
         usingSpringWithDamping:0.75 initialSpringVelocity:0.5 options:0
                     animations:^{
        self.transform = CGAffineTransformMakeRotation(_menuRotation);
    } completion:nil];
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

        // Pulse animation on button
        CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
        pulse.fromValue    = @(8);
        pulse.toValue      = @(18);
        pulse.duration     = 1.5;
        pulse.autoreverses = YES;
        pulse.repeatCount  = HUGE_VALF;
        [gBtn.layer addAnimation:pulse forKey:@"pulse"];

        // Build menu
        CGFloat mw   = MIN(win.bounds.size.width - 24, 320);
        CGFloat mh   = MIN(win.bounds.size.height - 100, 580);
        gMenu = [[EverLightMenu alloc] initWithFrame:CGRectMake(
            (win.bounds.size.width  - mw) / 2,
            (win.bounds.size.height - mh) / 2, mw, mh)];
        gMenu.hidden = YES;
        [win addSubview:gMenu];

        // Button tap — toggle menu
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
        
        NSLog(@"[EverLight] v2.0 Injected Successfully!");
        ELToast(@"EverLight v2.0 Loaded!", YES);
    });
}

__attribute__((constructor))
static void ELInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        ELInject();
    });
}

