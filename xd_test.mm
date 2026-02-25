#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>

#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <stdint.h>
#import <stddef.h>
#import <string.h>
#import <objc/runtime.h>

static NSInteger spawnQuantity = 1;
static float customSpawnX = 0.0f;
static float customSpawnY = 3.0f;
static float customSpawnZ = 0.0f;
static BOOL useCustomLocation = NO;
static NSInteger selectedItemIndex = 0;
static NSInteger selectedPresetLocation = 0;
static NSArray *availableItems = nil;
static NSArray *filteredItems = nil;

static void *il2cppHandle = NULL;
static BOOL isInitialized = NO;

/* Il2Cpp function pointers using opaque pointer types (safer on Clang/Apple) */
static void *(*il2cpp_domain_get)(void);
static void **(*il2cpp_domain_get_assemblies)(void *domain, size_t *out_count);
static void *(*il2cpp_assembly_get_image)(void *assembly);
static const char *(*il2cpp_image_get_name)(void *image);
static void *(*il2cpp_class_from_name)(void *image, const char *nspace, const char *name);
static void *(*il2cpp_class_get_method_from_name)(void *klass, const char *name, int args);
static void *(*il2cpp_runtime_invoke)(void *method, void *obj, void **params, void **exc);
static void *(*il2cpp_resolve_icall)(const char *);
static void *(*il2cpp_class_get_field_from_name)(void *klass, const char *name);
static void (*il2cpp_field_set_value)(void *obj, void *field, void *value);
static void (*il2cpp_field_get_value)(void *obj, void *field, void *out);
static void *(*il2cpp_class_get_type)(void *klass);
static void *(*il2cpp_type_get_object)(void *type);
static void *(*il2cpp_string_new)(const char *);

/* Game / class / method handles as opaque pointers */
static void *gameImage = NULL;
static void *unityImage = NULL;
static void *netPlayerClass = NULL;
static void *prefabGeneratorClass = NULL;
static void *gameObjectClass = NULL;
static void *transformClass = NULL;
static void *objectClass = NULL;
static void *gameManagerClass = NULL;
static void *getLocalPlayerMethod = NULL;
static void *giveSelfMoneyMethod = NULL;
static void *spawnItemMethod = NULL;
static void *findObjectOfTypeMethod = NULL;
static void *itemSellingMachineClass = NULL;
static void *rpcAddPlayerMoneyToAllMethod = NULL;
static void *gameManagerAddPlayerMoneyMethod = NULL;
static void *Transform_get_position_Injected = NULL;

static UIButton *menuButton = nil;
static id menuController = nil;

typedef struct { float x; float y; float z; } Vec3;

static NSArray *presetLocationNames;
static Vec3 presetLocationCoords[13];

static void *getImage(const char *name) {
    if (!isInitialized) return NULL;
    void *domain = il2cpp_domain_get();
    if (!domain) return NULL;
    size_t count = 0;
    void **assemblies = il2cpp_domain_get_assemblies(domain, &count);
    if (!assemblies) return NULL;
    for (size_t i = 0; i < count; i++) {
        void *assembly = assemblies[i];
        void *image = il2cpp_assembly_get_image(assembly);
        const char *imgName = il2cpp_image_get_name(image);
        if (imgName && strcmp(imgName, name) == 0) return image;
    }
    return NULL;
}

static BOOL initializeIL2CPP(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework")) {
            il2cppHandle = dlopen(name, RTLD_NOW);
            break;
        }
    }
    if (!il2cppHandle) il2cppHandle = dlopen(NULL, RTLD_NOW);
    if (!il2cppHandle) return NO;

    /* cast dlsym results to the correct function-pointer type using typeof to avoid warnings */
    il2cpp_domain_get = (typeof(il2cpp_domain_get))dlsym(il2cppHandle, "il2cpp_domain_get");
    il2cpp_domain_get_assemblies = (typeof(il2cpp_domain_get_assemblies))dlsym(il2cppHandle, "il2cpp_domain_get_assemblies");
    il2cpp_assembly_get_image = (typeof(il2cpp_assembly_get_image))dlsym(il2cppHandle, "il2cpp_assembly_get_image");
    il2cpp_image_get_name = (typeof(il2cpp_image_get_name))dlsym(il2cppHandle, "il2cpp_image_get_name");
    il2cpp_class_from_name = (typeof(il2cpp_class_from_name))dlsym(il2cppHandle, "il2cpp_class_from_name");
    il2cpp_class_get_method_from_name = (typeof(il2cpp_class_get_method_from_name))dlsym(il2cppHandle, "il2cpp_class_get_method_from_name");
    il2cpp_string_new = (typeof(il2cpp_string_new))dlsym(il2cppHandle, "il2cpp_string_new");
    il2cpp_runtime_invoke = (typeof(il2cpp_runtime_invoke))dlsym(il2cppHandle, "il2cpp_runtime_invoke");
    il2cpp_resolve_icall = (typeof(il2cpp_resolve_icall))dlsym(il2cppHandle, "il2cpp_resolve_icall");
    il2cpp_class_get_field_from_name = (typeof(il2cpp_class_get_field_from_name))dlsym(il2cppHandle, "il2cpp_class_get_field_from_name");
    il2cpp_field_get_value = (typeof(il2cpp_field_get_value))dlsym(il2cppHandle, "il2cpp_field_get_value");
    il2cpp_field_set_value = (typeof(il2cpp_field_set_value))dlsym(il2cppHandle, "il2cpp_field_set_value");
    il2cpp_class_get_type = (typeof(il2cpp_class_get_type))dlsym(il2cppHandle, "il2cpp_class_get_type");
    il2cpp_type_get_object = (typeof(il2cpp_type_get_object))dlsym(il2cppHandle, "il2cpp_type_get_object");

    if (il2cpp_domain_get && il2cpp_class_from_name && il2cpp_class_get_method_from_name && il2cpp_class_get_type && il2cpp_type_get_object) {
        Transform_get_position_Injected = il2cpp_resolve_icall("UnityEngine.Transform::get_position_Injected");
        isInitialized = YES;
        return YES;
    }
    return NO;
}

static BOOL initializeGameClasses(void) {
    if (!isInitialized) return NO;
    gameImage = getImage("AnimalCompany.dll");
    if (!gameImage) return NO;
    unityImage = getImage("UnityEngine.CoreModule.dll");
    netPlayerClass = il2cpp_class_from_name(gameImage, "AnimalCompany", "NetPlayer");
    prefabGeneratorClass = il2cpp_class_from_name(gameImage, "AnimalCompany", "PrefabGenerator");
    if (unityImage) {
        gameObjectClass = il2cpp_class_from_name(unityImage, "UnityEngine", "GameObject");
        transformClass = il2cpp_class_from_name(unityImage, "UnityEngine", "Transform");
    }
    if (!netPlayerClass) return NO;
    getLocalPlayerMethod = il2cpp_class_get_method_from_name(netPlayerClass, "get_localPlayer", 0);
    giveSelfMoneyMethod = il2cpp_class_get_method_from_name(netPlayerClass, "AddPlayerMoney", 1);
    if (prefabGeneratorClass)
        spawnItemMethod = il2cpp_class_get_method_from_name(prefabGeneratorClass, "SpawnItem", 4);
    if (unityImage) {
        objectClass = il2cpp_class_from_name(unityImage, "UnityEngine", "Object");
        if (objectClass)
            findObjectOfTypeMethod = il2cpp_class_get_method_from_name(objectClass, "FindObjectOfType", 1);
    }
    itemSellingMachineClass = il2cpp_class_from_name(gameImage, "AnimalCompany", "ItemSellingMachineController");
    if (itemSellingMachineClass) {
        rpcAddPlayerMoneyToAllMethod = il2cpp_class_get_method_from_name(itemSellingMachineClass, "RPC_AddPlayerMoneyToAll", 1);
        if (!rpcAddPlayerMoneyToAllMethod)
            rpcAddPlayerMoneyToAllMethod = il2cpp_class_get_method_from_name(itemSellingMachineClass, "RPC_AddPlayerMoneyToAll", 2);
    }
    gameManagerClass = il2cpp_class_from_name(gameImage, "AnimalCompany", "GameManager");
    if (gameManagerClass)
        gameManagerAddPlayerMoneyMethod = il2cpp_class_get_method_from_name(gameManagerClass, "AddPlayerMoney", 1);
    return YES;
}

static void *getLocalPlayer(void) {
    if (!netPlayerClass) netPlayerClass = il2cpp_class_from_name(gameImage, "AnimalCompany", "NetPlayer");
    if (!netPlayerClass) return NULL;
    if (!getLocalPlayerMethod) getLocalPlayerMethod = il2cpp_class_get_method_from_name(netPlayerClass, "get_localPlayer", 0);
    if (!getLocalPlayerMethod) return NULL;
    void *exc = NULL;
    void *result = il2cpp_runtime_invoke(getLocalPlayerMethod, NULL, NULL, &exc);
    if (exc) return NULL;
    return result;
}

static float getPlayerPosition(void) {
    return 0.0f;
}

static float getSpawnPosition(void) {
    if (useCustomLocation) return customSpawnX;
    if (getLocalPlayer()) return getPlayerPosition();
    return 0.0f;
}

static void giveSelfMoney(unsigned int amount) {
    if (!giveSelfMoneyMethod) {
        NSLog(@"[ACMod] giveSelfMoney: AddPlayerMoney method not found, initializing...");
        if (netPlayerClass)
            giveSelfMoneyMethod = il2cpp_class_get_method_from_name(netPlayerClass, "AddPlayerMoney", 1);
    }
    if (!giveSelfMoneyMethod) {
        NSLog(@"[ACMod] Failed to initialize AddPlayerMoney method");
        return;
    }
    void *player = getLocalPlayer();
    if (!player) { NSLog(@"[ACMod] Could not get local player instance"); return; }
    unsigned int val = amount;
    void *args[] = { &val };
    void *exc = NULL;
    il2cpp_runtime_invoke(giveSelfMoneyMethod, player, args, &exc);
    if (exc) NSLog(@"[ACMod] Exception while giving money: %p", exc);
    else NSLog(@"[ACMod] Successfully gave %u money to local player", amount);
}

static void giveAllPlayersMoney(int amount) {
    if (rpcAddPlayerMoneyToAllMethod && findObjectOfTypeMethod && il2cpp_class_get_type && il2cpp_type_get_object) {
        void *type = il2cpp_class_get_type(itemSellingMachineClass);
        void *obj = il2cpp_type_get_object(type);
        void *exc = NULL;
        void *findArgs[] = { &obj };
        void *controller = il2cpp_runtime_invoke(findObjectOfTypeMethod, NULL, findArgs, &exc);
        if (!controller || exc) {
            NSLog(@"[ACMod] ItemSellingMachine controller not found or findObjectOfType had exception");
        } else {
            NSLog(@"[ACMod] Found ItemSellingMachine controller, trying RPC_AddPlayerMoneyToAll");
            int val = amount;
            void *args1[] = { &val };
            exc = NULL;
            il2cpp_runtime_invoke(rpcAddPlayerMoneyToAllMethod, controller, args1, &exc);
            if (!exc) { NSLog(@"[ACMod] RPC_AddPlayerMoneyToAll invoked successfully with single int param"); return; }
            NSLog(@"[ACMod] RPC_AddPlayerMoneyToAll (int) exception occurred, trying (int,RpcInfo) fallback");
            void *args2[] = { &val, NULL };
            exc = NULL;
            il2cpp_runtime_invoke(rpcAddPlayerMoneyToAllMethod, controller, args2, &exc);
            if (!exc) { NSLog(@"[ACMod] RPC_AddPlayerMoneyToAll invoked successfully with (int,RpcInfo=NULL)"); return; }
            NSLog(@"[ACMod] RPC_AddPlayerMoneyToAll fallback also failed");
        }
    } else {
        NSLog(@"[ACMod] RPC_AddPlayerMoneyToAll method or helpers not available");
    }
    if (gameManagerAddPlayerMoneyMethod) {
        NSLog(@"[ACMod] Trying GameManager.AddPlayerMoney as fallback");
        int val = amount;
        void *args[] = { &val };
        void *exc = NULL;
        il2cpp_runtime_invoke(gameManagerAddPlayerMoneyMethod, NULL, args, &exc);
        if (!exc) { NSLog(@"[ACMod] GameManager.AddPlayerMoney invoked successfully"); return; }
        NSLog(@"[ACMod] GameManager.AddPlayerMoney invocation threw an exception");
    } else {
        NSLog(@"[ACMod] GameManager.AddPlayerMoney method not found");
    }
    NSLog(@"[ACMod] Falling back to giveSelfMoney for amount %d", amount);
    giveSelfMoney(amount);
}

static void spawnItem(NSString *itemName, int quantity, float x, float y, float z) {
    if (!spawnItemMethod || !il2cpp_string_new) return;
    void *nameStr = il2cpp_string_new([itemName UTF8String]);
    float scale = 1.0f;
    (void)scale;
    void *args[] = { &nameStr, &quantity, &x, &y, &z };
    void *exc = NULL;
    il2cpp_runtime_invoke(spawnItemMethod, NULL, args, &exc);
}

static NSArray *initializeLists(void) {
    NSArray *items = @[
        @"item_ac_cola", @"item_alphablade", @"item_anti_gravity_grenade", @"item_apple",
        @"item_arena_pistol", @"item_arena_shotgun", @"item_arrow", @"item_arrow_bomb",
        @"item_arrow_heart", @"item_arrow_lightbulb", @"item_arrow_teleport", @"item_axe",
        @"item_backpack", @"item_backpack_black", @"item_backpack_green", @"item_backpack_large_base",
        @"item_backpack_large_basketball", @"item_backpack_large_clover", @"item_backpack_pink",
        @"item_backpack_realistic", @"item_backpack_small_base", @"item_backpack_white",
        @"item_backpack_with_flashlight", @"item_balloon", @"item_balloon_heart", @"item_banana",
        @"item_banana_chips", @"item_baseball_bat", @"item_basic_fishing_rod", @"item_beans",
        @"item_big_cup", @"item_bighead_larva", @"item_bloodlust_vial", @"item_boombox",
        @"item_boombox_neon", @"item_boomerang", @"item_box_fan", @"item_brain_chunk",
        @"item_brick", @"item_broccoli_grenade", @"item_broccoli_shrink_grenade", @"item_broom",
        @"item_broom_halloween", @"item_burrito", @"item_calculator", @"item_cardboard_box",
        @"item_ceo_plaque", @"item_clapper", @"item_cluster_grenade", @"item_coconut_shell",
        @"item_cola", @"item_cola_large", @"item_company_ration", @"item_company_ration_heal",
        @"item_cracker", @"item_crate", @"item_crossbow", @"item_crossbow_heart", @"item_crowbar",
        @"item_cutie_dead", @"item_d20", @"item_demon_sword", @"item_disc",
        @"item_disposable_camera", @"item_drill", @"item_drill_neon", @"item_dynamite",
        @"item_dynamite_cube", @"item_egg", @"item_electrical_tape", @"item_eraser",
        @"item_film_reel", @"item_finger_board", @"item_fish_dumb_fish", @"item_flamethrower",
        @"item_flamethrower_skull", @"item_flamethrower_skull_ruby", @"item_flaregun",
        @"item_flashbang", @"item_flashlight", @"item_flashlight_mega", @"item_flashlight_red",
        @"item_flipflop_realistic", @"item_floppy3", @"item_floppy5", @"item_football",
        @"item_friend_launcher", @"item_frying_pan", @"item_gameboy", @"item_glowstick",
        @"item_goldbar", @"item_goldcoin", @"item_goop", @"item_goopfish", @"item_great_sword",
        @"item_grenade", @"item_grenade_gold", @"item_grenade_launcher", @"item_guided_boomerang",
        @"item_harddrive", @"item_hatchet", @"item_hawaiian_drum", @"item_heart_chunk",
        @"item_heart_gun", @"item_heartchocolatebox", @"item_hh_key", @"item_hookshot",
        @"item_hookshot_sword", @"item_hot_cocoa", @"item_hoverpad", @"item_impulse_grenade",
        @"item_jetpack", @"item_joystick", @"item_joystick_inv_y", @"item_keycard",
        @"item_lance", @"item_landmine", @"item_large_banana", @"item_megaphone",
        @"item_metal_ball", @"item_metal_ball_x", @"item_metal_plate", @"item_metal_plate_2",
        @"item_metal_rod", @"item_metal_rod_xmas", @"item_metal_triangle", @"item_momboss_box",
        @"item_moneygun", @"item_motor", @"item_mountain_key", @"item_mug", @"item_needle",
        @"item_nut", @"item_nut_drop", @"item_ogre_hands", @"item_ore_copper_large",
        @"item_ore_copper_medium", @"item_ore_copper_small", @"item_ore_gold_large",
        @"item_ore_gold_medium", @"item_ore_gold_small", @"item_ore_iron_large",
        @"item_ore_iron_medium", @"item_ore_iron_small", @"item_paintball_gun",
        @"item_paper_bag", @"item_pepper_spray", @"item_pie", @"item_pillow",
        @"item_ping_pong_ball", @"item_ping_pong_paddle", @"item_pipe", @"item_plank",
        @"item_playing_card", @"item_popcorn", @"item_potato", @"item_potato_chips",
        @"item_present", @"item_present_1", @"item_present_2", @"item_present_3",
        @"item_pumpkin", @"item_rainstick", @"item_remote_bomb", @"item_remote_bomb_detonator",
        @"item_revolver", @"item_rock", @"item_rock_large", @"item_rope",
        @"item_rpg", @"item_rpg_rocket", @"item_rubber_duck", @"item_salt",
        @"item_scissors", @"item_shield", @"item_shovel", @"item_shuriken",
        @"item_skateboard", @"item_ski_mask", @"item_skull", @"item_slime",
        @"item_slime_ball", @"item_smoke_grenade", @"item_snowball", @"item_snowball_launcher",
        @"item_soda_can", @"item_spear", @"item_spike_trap", @"item_spring",
        @"item_staff", @"item_stink_bomb", @"item_stopwatch", @"item_sword",
        @"item_table_leg", @"item_tape", @"item_tazer", @"item_tennis_ball",
        @"item_tennis_racket", @"item_tire", @"item_tomato", @"item_torch",
        @"item_toy_car", @"item_trampoline", @"item_trophy", @"item_umbrella",
        @"item_vacuum", @"item_volleyball", @"item_watering_can", @"item_whip",
        @"item_whistle", @"item_wrench", @"item_xmas_sword", @"item_xmas_tree",
        @"item_yo_yo"
    ];
    availableItems = items;
    return items;
}

static id loadSettings(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    spawnQuantity = [d integerForKey:@"ACMod_spawnQuantity"] ?: 1;
    customSpawnX = [d floatForKey:@"ACMod_customSpawnX"];
    customSpawnY = [d floatForKey:@"ACMod_customSpawnY"] ?: 3.0f;
    customSpawnZ = [d floatForKey:@"ACMod_customSpawnZ"];
    useCustomLocation = [d boolForKey:@"ACMod_useCustomLocation"];
    selectedItemIndex = [d integerForKey:@"ACMod_selectedItemIndex"];
    selectedPresetLocation = [d integerForKey:@"ACMod_selectedPresetLocation"];
    return nil;
}

static BOOL saveSettings(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setInteger:spawnQuantity forKey:@"ACMod_spawnQuantity"];
    [d setFloat:customSpawnX forKey:@"ACMod_customSpawnX"];
    [d setFloat:customSpawnY forKey:@"ACMod_customSpawnY"];
    [d setFloat:customSpawnZ forKey:@"ACMod_customSpawnZ"];
    [d setBool:useCustomLocation forKey:@"ACMod_useCustomLocation"];
    [d setInteger:selectedItemIndex forKey:@"ACMod_selectedItemIndex"];
    [d setInteger:selectedPresetLocation forKey:@"ACMod_selectedPresetLocation"];
    [d synchronize];
    return YES;
}

@interface ModMenuController : UIViewController <UIPickerViewDelegate, UIPickerViewDataSource>
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIScrollView *contentScrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIPickerView *itemPicker;
@property (nonatomic, strong) UILabel *quantityLabel;
@property (nonatomic, strong) UIStepper *quantityStepper;
@property (nonatomic, strong) CAGradientLayer *containerGradient;
@property (nonatomic, strong) UISegmentedControl *tabControl;
@property (nonatomic, assign) NSInteger currentTab;
@end

@implementation ModMenuController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
    self.modalPresentationStyle = UIModalPresentationOverCurrentContext;
    self.currentTab = 0;
    [self setupUI];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self updateLayoutForOrientation];
}

- (void)updateLayoutForOrientation {
    CGRect bounds = self.view.bounds;
    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;
    CGFloat containerW, containerH;
    if (w > h) {
        containerW = MIN(h * 0.85f, 480.0f);
        containerH = MIN(h * 0.92f, 340.0f);
    } else {
        containerW = MIN(w * 0.88f, 400.0f);
        containerH = MIN(h * 0.7f, 580.0f);
    }
    self.containerView.frame = CGRectMake((w - containerW) / 2.0f, (h - containerH) / 2.0f, containerW, containerH);
    if (self.containerGradient) {
        self.containerGradient.frame = self.containerView.bounds;
    }
    [self layoutSubviewsInContainer:containerH];
}

- (void)setupUI {
    CGRect bounds = self.view.bounds;
    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;
    CGFloat containerW = MIN(w * 0.88f, 400.0f);
    CGFloat containerH = MIN(h * 0.7f, 580.0f);

    self.containerView = [[UIView alloc] initWithFrame:CGRectMake((w - containerW) / 2.0f, (h - containerH) / 2.0f, containerW, containerH)];
    self.containerView.layer.cornerRadius = 18.0f;
    self.containerView.layer.masksToBounds = YES;
    [self.view addSubview:self.containerView];

    self.containerGradient = [CAGradientLayer layer];
    self.containerGradient.frame = self.containerView.bounds;
    self.containerGradient.colors = @[
        (id)[[UIColor colorWithRed:0.12f green:0.07f blue:0.18f alpha:0.97f] CGColor],
        (id)[[UIColor colorWithRed:0.22f green:0.10f blue:0.28f alpha:0.97f] CGColor]
    ];
    self.containerGradient.startPoint = CGPointMake(0.0f, 0.0f);
    self.containerGradient.endPoint = CGPointMake(0.0f, 1.0f);
    self.containerGradient.cornerRadius = 18.0f;
    [self.containerView.layer insertSublayer:self.containerGradient atIndex:0];

    self.containerView.layer.borderWidth = 2.0f;
    self.containerView.layer.borderColor = [[UIColor colorWithRed:0.85f green:0.4f blue:0.15f alpha:0.7f] CGColor];

    [self layoutSubviewsInContainer:containerH];
}

- (void)layoutSubviewsInContainer:(CGFloat)containerH {
    for (UIView *v in [self.containerView.subviews copy]) {
        if (v != (UIView *)self.containerGradient) [v removeFromSuperview];
    }

    CGFloat cw = self.containerView.bounds.size.width;
    CGFloat ch = self.containerView.bounds.size.height;
    CGFloat pad = 10.0f;

    UIButton *keyboardBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    keyboardBtn.frame = CGRectMake(pad, pad, 36.0f, 36.0f);
    [keyboardBtn setTitle:@"⌨" forState:UIControlStateNormal];
    [keyboardBtn setBackgroundColor:[UIColor colorWithRed:0.2f green:0.14f blue:0.26f alpha:0.9f]];
    keyboardBtn.layer.cornerRadius = 18.0f;
    keyboardBtn.titleLabel.font = [UIFont systemFontOfSize:18.0f];
    [keyboardBtn addTarget:self action:@selector(openKeyboard) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:keyboardBtn];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(50.0f, pad, cw - 100.0f, 36.0f)];
    titleLabel.text = @"=XD=";
    titleLabel.textColor = [UIColor colorWithRed:1.0f green:0.6f blue:0.2f alpha:1.0f];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont systemFontOfSize:28.0f weight:UIFontWeightHeavy];
    [self.containerView addSubview:titleLabel];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(cw - 46.0f, pad, 36.0f, 36.0f);
    [closeBtn setTitle:@"×" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeBtn setBackgroundColor:[UIColor colorWithRed:0.8f green:0.25f blue:0.25f alpha:0.85f]];
    closeBtn.layer.cornerRadius = 18.0f;
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:26.0f weight:UIFontWeightMedium];
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:closeBtn];

    CGFloat tabY = pad + 36.0f + 6.0f;
    self.tabControl = [[UISegmentedControl alloc] initWithItems:@[@"Items", @"Settings"]];
    self.tabControl.frame = CGRectMake(pad, tabY, cw - pad * 2.0f, 32.0f);
    self.tabControl.selectedSegmentIndex = self.currentTab;
    self.tabControl.backgroundColor = [UIColor colorWithRed:0.18f green:0.12f blue:0.24f alpha:1.0f];
    self.tabControl.selectedSegmentTintColor = [UIColor colorWithRed:0.55f green:0.2f blue:0.75f alpha:1.0f];
    NSDictionary *normalAttrs = @{ NSForegroundColorAttributeName: [UIColor colorWithWhite:0.7f alpha:1.0f] };
    NSDictionary *selectedAttrs = @{ NSForegroundColorAttributeName: [UIColor whiteColor] };
    [self.tabControl setTitleTextAttributes:normalAttrs forState:UIControlStateNormal];
    [self.tabControl setTitleTextAttributes:selectedAttrs forState:UIControlStateSelected];
    [self.tabControl addTarget:self action:@selector(tabChanged:) forControlEvents:UIControlEventValueChanged];
    [self.containerView addSubview:self.tabControl];

    CGFloat scrollY = tabY + 32.0f + 6.0f;
    CGFloat scrollH = ch - scrollY - pad;
    self.contentScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(pad, scrollY, cw - pad * 2.0f, scrollH)];
    self.contentScrollView.backgroundColor = [UIColor colorWithRed:0.1f green:0.06f blue:0.15f alpha:0.5f];
    self.contentScrollView.layer.cornerRadius = 12.0f;
    self.contentScrollView.showsVerticalScrollIndicator = YES;
    self.contentScrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    [self.containerView addSubview:self.contentScrollView];

    self.contentView = [[UIView alloc] initWithFrame:self.contentScrollView.bounds];
    self.contentView.backgroundColor = [UIColor clearColor];
    [self.contentScrollView addSubview:self.contentView];

    [self loadCurrentTab];
}

- (void)tabChanged:(UISegmentedControl *)sender {
    self.currentTab = sender.selectedSegmentIndex;
    saveSettings();
    [self loadCurrentTab];
}

- (void)loadCurrentTab {
    for (UIView *v in [self.contentView.subviews copy]) [v removeFromSuperview];
    if (self.currentTab == 0)
        [self loadItemsTab];
    else
        [self loadSettingsTab];
}

- (void)loadItemsTab {
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat pad = 8.0f;
    CGFloat y = pad;

    UIView *spawnerCard = [[UIView alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2.0f, 300.0f)];
    spawnerCard.backgroundColor = [UIColor colorWithRed:0.16f green:0.10f blue:0.22f alpha:0.9f];
    spawnerCard.layer.cornerRadius = 10.0f;
    spawnerCard.layer.borderWidth = 1.0f;
    spawnerCard.layer.borderColor = [[UIColor colorWithRed:0.7f green:0.3f blue:0.9f alpha:0.7f] CGColor];
    [self.contentView addSubview:spawnerCard];

    UILabel *spawnerTitle = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, 8.0f, spawnerCard.bounds.size.width - 20.0f, 22.0f)];
    spawnerTitle.text = @"Item Spawner";
    spawnerTitle.textColor = [UIColor colorWithRed:0.75f green:0.4f blue:1.0f alpha:1.0f];
    spawnerTitle.font = [UIFont systemFontOfSize:17.0f weight:UIFontWeightSemibold];
    [spawnerCard addSubview:spawnerTitle];

    UITextField *searchField = [[UITextField alloc] initWithFrame:CGRectMake(10.0f, 36.0f, spawnerCard.bounds.size.width - 20.0f, 32.0f)];
    searchField.backgroundColor = [UIColor colorWithRed:0.22f green:0.16f blue:0.28f alpha:0.9f];
    searchField.textColor = [UIColor whiteColor];
    searchField.layer.cornerRadius = 8.0f;
    searchField.textAlignment = NSTextAlignmentLeft;
    searchField.font = [UIFont systemFontOfSize:14.0f];
    searchField.tag = 1000;
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 32)];
    searchField.leftView = paddingView;
    searchField.leftViewMode = UITextFieldViewModeAlways;
    NSAttributedString *placeholder = [[NSAttributedString alloc] initWithString:@"Search..."
        attributes:@{ NSForegroundColorAttributeName: [UIColor colorWithWhite:0.5f alpha:1.0f] }];
    searchField.attributedPlaceholder = placeholder;
    [searchField addTarget:self action:@selector(searchItemsWithTextField:) forControlEvents:UIControlEventEditingChanged];
    [spawnerCard addSubview:searchField];

    self.itemPicker = [[UIPickerView alloc] initWithFrame:CGRectMake(10.0f, 74.0f, spawnerCard.bounds.size.width - 20.0f, 120.0f)];
    self.itemPicker.delegate = self;
    self.itemPicker.dataSource = self;
    self.itemPicker.tag = 100;
    self.itemPicker.backgroundColor = [UIColor colorWithRed:0.2f green:0.14f blue:0.24f alpha:0.8f];
    self.itemPicker.layer.cornerRadius = 8.0f;
    if (selectedItemIndex < (NSInteger)[availableItems count])
        [self.itemPicker selectRow:selectedItemIndex inComponent:0 animated:NO];
    [spawnerCard addSubview:self.itemPicker];

    CGFloat qy = 74.0f + 120.0f + 8.0f;
    UILabel *qtyTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, qy, 80.0f, 22.0f)];
    qtyTitleLabel.text = @"Quantity";
    qtyTitleLabel.textColor = [UIColor colorWithWhite:0.7f alpha:1.0f];
    qtyTitleLabel.font = [UIFont systemFontOfSize:14.0f weight:UIFontWeightMedium];
    [spawnerCard addSubview:qtyTitleLabel];

    self.quantityLabel = [[UILabel alloc] initWithFrame:CGRectMake(90.0f, qy, 50.0f, 22.0f)];
    self.quantityLabel.text = [NSString stringWithFormat:@"%ld", (long)spawnQuantity];
    self.quantityLabel.textColor = [UIColor whiteColor];
    self.quantityLabel.font = [UIFont systemFontOfSize:19.0f weight:UIFontWeightBold];
    self.quantityLabel.textAlignment = NSTextAlignmentCenter;
    [spawnerCard addSubview:self.quantityLabel];

    CGFloat sw = spawnerCard.bounds.size.width - 20.0f;
    self.quantityStepper = [[UIStepper alloc] initWithFrame:CGRectMake(sw - 94.0f + 10.0f, qy - 4.0f, 94.0f, 29.0f)];
    self.quantityStepper.minimumValue = 1;
    self.quantityStepper.maximumValue = 100;
    self.quantityStepper.value = (double)spawnQuantity;
    self.quantityStepper.tintColor = [UIColor colorWithRed:0.7f green:0.35f blue:0.9f alpha:1.0f];
    [self.quantityStepper addTarget:self action:@selector(quantityChanged:) forControlEvents:UIControlEventValueChanged];
    [spawnerCard addSubview:self.quantityStepper];

    CGFloat btnY = qy + 28.0f + 6.0f;
    UIButton *spawnBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    spawnBtn.frame = CGRectMake(10.0f, btnY, spawnerCard.bounds.size.width - 20.0f, 36.0f);
    [spawnBtn setTitle:@"Spawn Item" forState:UIControlStateNormal];
    [spawnBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    spawnBtn.titleLabel.font = [UIFont systemFontOfSize:17.0f weight:UIFontWeightSemibold];
    spawnBtn.backgroundColor = [UIColor colorWithRed:0.65f green:0.3f blue:0.85f alpha:1.0f];
    spawnBtn.layer.cornerRadius = 8.0f;
    [spawnBtn addTarget:self action:@selector(spawnSelectedItem) forControlEvents:UIControlEventTouchUpInside];
    [spawnerCard addSubview:spawnBtn];

    CGFloat infoY = btnY + 36.0f + 6.0f;
    UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, infoY, spawnerCard.bounds.size.width - 20.0f, 30.0f)];
    infoLabel.text = useCustomLocation ? @"Using custom spawn location" : @"Spawning at player position";
    infoLabel.textColor = [UIColor colorWithWhite:0.55f alpha:1.0f];
    infoLabel.font = [UIFont systemFontOfSize:11.0f];
    infoLabel.textAlignment = NSTextAlignmentCenter;
    infoLabel.numberOfLines = 2;
    [spawnerCard addSubview:infoLabel];

    CGFloat spawnerH = infoY + 30.0f + 10.0f;
    spawnerCard.frame = CGRectMake(pad, y, w - pad * 2.0f, spawnerH);
    y += spawnerH + 8.0f;

    UIView *moneyCard = [[UIView alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2.0f, 90.0f)];
    moneyCard.backgroundColor = [UIColor colorWithRed:0.16f green:0.11f blue:0.2f alpha:0.8f];
    moneyCard.layer.cornerRadius = 10.0f;
    moneyCard.layer.borderWidth = 1.0f;
    moneyCard.layer.borderColor = [[UIColor colorWithRed:1.0f green:0.84f blue:0.0f alpha:0.6f] CGColor];
    [self.contentView addSubview:moneyCard];

    UILabel *moneyTitle = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, 8.0f, moneyCard.bounds.size.width - 20.0f, 22.0f)];
    moneyTitle.text = @"Money Cheat";
    moneyTitle.textColor = [UIColor colorWithRed:1.0f green:0.84f blue:0.0f alpha:1.0f];
    moneyTitle.font = [UIFont systemFontOfSize:17.0f weight:UIFontWeightSemibold];
    [moneyCard addSubview:moneyTitle];

    UIButton *moneyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    moneyBtn.frame = CGRectMake(10.0f, 36.0f, moneyCard.bounds.size.width - 20.0f, 36.0f);
    [moneyBtn setTitle:@"Give 9,999,999 Money" forState:UIControlStateNormal];
    [moneyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    moneyBtn.backgroundColor = [UIColor colorWithRed:1.0f green:0.84f blue:0.0f alpha:1.0f];
    moneyBtn.layer.cornerRadius = 8.0f;
    [moneyBtn addTarget:self action:@selector(giveBigMoney) forControlEvents:UIControlEventTouchUpInside];
    [moneyCard addSubview:moneyBtn];
    y += 90.0f + 8.0f;

    UIView *cheatsCard = [[UIView alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2.0f, 90.0f)];
    cheatsCard.backgroundColor = [UIColor colorWithRed:0.16f green:0.11f blue:0.2f alpha:0.8f];
    cheatsCard.layer.cornerRadius = 10.0f;
    cheatsCard.layer.borderWidth = 1.0f;
    cheatsCard.layer.borderColor = [[UIColor colorWithRed:1.0f green:0.6f blue:0.0f alpha:0.5f] CGColor];
    [self.contentView addSubview:cheatsCard];

    UILabel *cheatsTitle = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, 8.0f, cheatsCard.bounds.size.width - 20.0f, 22.0f)];
    cheatsTitle.text = @"Cheats";
    cheatsTitle.textColor = [UIColor colorWithRed:1.0f green:0.6f blue:0.0f alpha:1.0f];
    cheatsTitle.font = [UIFont systemFontOfSize:17.0f weight:UIFontWeightSemibold];
    [cheatsCard addSubview:cheatsTitle];

    UIButton *ammoBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    ammoBtn.frame = CGRectMake(10.0f, 36.0f, cheatsCard.bounds.size.width - 20.0f, 36.0f);
    [ammoBtn setTitle:@"Infinite Ammo" forState:UIControlStateNormal];
    [ammoBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    ammoBtn.backgroundColor = [UIColor colorWithRed:1.0f green:0.6f blue:0.0f alpha:1.0f];
    ammoBtn.layer.cornerRadius = 8.0f;
    [ammoBtn addTarget:self action:@selector(giveInfAmmo) forControlEvents:UIControlEventTouchUpInside];
    [cheatsCard addSubview:ammoBtn];
    y += 90.0f + 8.0f;

    UIView *shopCard = [[UIView alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2.0f, 90.0f)];
    shopCard.backgroundColor = [UIColor colorWithRed:0.16f green:0.11f blue:0.2f alpha:0.8f];
    shopCard.layer.cornerRadius = 10.0f;
    shopCard.layer.borderWidth = 1.0f;
    shopCard.layer.borderColor = [[UIColor colorWithRed:0.2f green:0.8f blue:0.8f alpha:0.3f] CGColor];
    [self.contentView addSubview:shopCard];

    UILabel *shopTitle = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, 8.0f, shopCard.bounds.size.width - 20.0f, 22.0f)];
    shopTitle.text = @"Shop";
    shopTitle.textColor = [UIColor colorWithRed:0.2f green:0.8f blue:0.8f alpha:1.0f];
    shopTitle.font = [UIFont systemFontOfSize:17.0f weight:UIFontWeightSemibold];
    [shopCard addSubview:shopTitle];

    UIButton *cooldownBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    cooldownBtn.frame = CGRectMake(10.0f, 36.0f, shopCard.bounds.size.width - 20.0f, 36.0f);
    [cooldownBtn setTitle:@"No Buy Cooldown" forState:UIControlStateNormal];
    [cooldownBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    cooldownBtn.titleLabel.font = [UIFont systemFontOfSize:14.0f weight:UIFontWeightSemibold];
    cooldownBtn.backgroundColor = [UIColor colorWithRed:0.2f green:0.8f blue:0.8f alpha:1.0f];
    cooldownBtn.layer.cornerRadius = 8.0f;
    [cooldownBtn addTarget:self action:@selector(removeShopCooldown) forControlEvents:UIControlEventTouchUpInside];
    [shopCard addSubview:cooldownBtn];
    y += 90.0f + 8.0f;

    UIView *communityCard = [[UIView alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2.0f, 90.0f)];
    communityCard.backgroundColor = [UIColor colorWithRed:0.16f green:0.11f blue:0.2f alpha:0.8f];
    communityCard.layer.cornerRadius = 10.0f;
    communityCard.layer.borderWidth = 1.0f;
    communityCard.layer.borderColor = [[UIColor colorWithRed:0.34f green:0.4f blue:0.95f alpha:0.5f] CGColor];
    [self.contentView addSubview:communityCard];

    UILabel *communityTitle = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, 8.0f, communityCard.bounds.size.width - 20.0f, 22.0f)];
    communityTitle.text = @"Community";
    communityTitle.textColor = [UIColor colorWithRed:0.34f green:0.4f blue:0.95f alpha:1.0f];
    communityTitle.font = [UIFont systemFontOfSize:17.0f weight:UIFontWeightSemibold];
    [communityCard addSubview:communityTitle];

    UIButton *discordBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    discordBtn.frame = CGRectMake(10.0f, 36.0f, communityCard.bounds.size.width - 20.0f, 36.0f);
    [discordBtn setTitle:@"Join Discord" forState:UIControlStateNormal];
    [discordBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    discordBtn.titleLabel.font = [UIFont systemFontOfSize:15.0f weight:UIFontWeightSemibold];
    discordBtn.backgroundColor = [UIColor colorWithRed:0.34f green:0.4f blue:0.95f alpha:1.0f];
    discordBtn.layer.cornerRadius = 8.0f;
    [discordBtn addTarget:self action:@selector(openDiscord) forControlEvents:UIControlEventTouchUpInside];
    [communityCard addSubview:discordBtn];
    y += 90.0f + 8.0f;

    CGFloat contentH = y + 8.0f;
    self.contentScrollView.contentSize = CGSizeMake(self.contentScrollView.bounds.size.width, contentH);
    self.contentView.frame = CGRectMake(0, 0, self.contentScrollView.bounds.size.width, contentH);
}

- (void)loadSettingsTab {
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat pad = 8.0f;
    CGFloat y = pad;

    UIView *presetCard = [[UIView alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2.0f, 200.0f)];
    presetCard.backgroundColor = [UIColor colorWithRed:0.16f green:0.11f blue:0.2f alpha:0.9f];
    presetCard.layer.cornerRadius = 10.0f;
    presetCard.layer.borderWidth = 1.0f;
    presetCard.layer.borderColor = [[UIColor colorWithRed:0.7f green:0.3f blue:0.9f alpha:0.5f] CGColor];
    [self.contentView addSubview:presetCard];

    UILabel *presetTitle = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, 8.0f, presetCard.bounds.size.width - 20.0f, 22.0f)];
    presetTitle.text = @"Preset Locations";
    presetTitle.textColor = [UIColor colorWithRed:0.75f green:0.4f blue:1.0f alpha:1.0f];
    presetTitle.font = [UIFont systemFontOfSize:17.0f weight:UIFontWeightSemibold];
    [presetCard addSubview:presetTitle];

    UIPickerView *presetPicker = [[UIPickerView alloc] initWithFrame:CGRectMake(10.0f, 36.0f, presetCard.bounds.size.width - 20.0f, 120.0f)];
    presetPicker.delegate = self;
    presetPicker.dataSource = self;
    presetPicker.tag = 5000;
    presetPicker.backgroundColor = [UIColor colorWithRed:0.2f green:0.14f blue:0.24f alpha:0.8f];
    presetPicker.layer.cornerRadius = 8.0f;
    [presetPicker selectRow:selectedPresetLocation inComponent:0 animated:NO];
    [presetCard addSubview:presetPicker];
    y += 200.0f + 8.0f;

    if (selectedPresetLocation == 0) {
        UIView *customCard = [[UIView alloc] initWithFrame:CGRectMake(pad, y, w - pad * 2.0f, 220.0f)];
        customCard.backgroundColor = [UIColor colorWithRed:0.16f green:0.11f blue:0.2f alpha:0.9f];
        customCard.layer.cornerRadius = 10.0f;
        customCard.layer.borderWidth = 1.0f;
        customCard.layer.borderColor = [[UIColor colorWithRed:1.0f green:0.6f blue:0.2f alpha:0.5f] CGColor];
        [self.contentView addSubview:customCard];

        UILabel *customTitle = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, 8.0f, customCard.bounds.size.width - 20.0f, 22.0f)];
        customTitle.text = @"Custom Location";
        customTitle.textColor = [UIColor colorWithRed:1.0f green:0.6f blue:0.2f alpha:1.0f];
        customTitle.font = [UIFont systemFontOfSize:17.0f weight:UIFontWeightSemibold];
        [customCard addSubview:customTitle];

        UILabel *useCustomLabel = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, 38.0f, customCard.bounds.size.width - 80.0f, 22.0f)];
        useCustomLabel.text = @"Use Custom Location";
        useCustomLabel.textColor = [UIColor colorWithWhite:0.85f alpha:1.0f];
        useCustomLabel.font = [UIFont systemFontOfSize:14.0f weight:UIFontWeightMedium];
        [customCard addSubview:useCustomLabel];

        UISwitch *customSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(customCard.bounds.size.width - 60.0f, 34.0f, 51.0f, 31.0f)];
        customSwitch.on = useCustomLocation;
        customSwitch.onTintColor = [UIColor colorWithRed:0.7f green:0.35f blue:0.9f alpha:1.0f];
        customSwitch.tag = 2000;
        [customSwitch addTarget:self action:@selector(toggleCustomLocation:) forControlEvents:UIControlEventValueChanged];
        [customCard addSubview:customSwitch];

        CGFloat fieldY = 70.0f;
        NSArray *labels = @[@"X", @"Y", @"Z"];
        NSArray *tags = @[@3001, @3002, @3003];
        float vals[3] = { customSpawnX, customSpawnY, customSpawnZ };
        for (int i = 0; i < 3; i++) {
            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, fieldY, 20.0f, 28.0f)];
            lbl.text = labels[i];
            lbl.textColor = [UIColor colorWithWhite:0.75f alpha:1.0f];
            lbl.font = [UIFont systemFontOfSize:15.0f weight:UIFontWeightMedium];
            [customCard addSubview:lbl];

            UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(36.0f, fieldY, customCard.bounds.size.width - 46.0f, 28.0f)];
            tf.text = [NSString stringWithFormat:@"%.2f", vals[i]];
            tf.backgroundColor = [UIColor colorWithRed:0.22f green:0.16f blue:0.28f alpha:0.9f];
            tf.textColor = [UIColor whiteColor];
            tf.layer.cornerRadius = 6.0f;
            tf.textAlignment = NSTextAlignmentCenter;
            tf.keyboardType = UIKeyboardTypeDecimalPad;
            tf.font = [UIFont systemFontOfSize:14.0f];
            tf.tag = [tags[i] integerValue];
            tf.enabled = YES;
            [tf addTarget:self action:@selector(updateLocationFromFields) forControlEvents:UIControlEventEditingChanged];
            [customCard addSubview:tf];
            fieldY += 34.0f;
        }

        UIButton *resetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        resetBtn.frame = CGRectMake(10.0f, fieldY + 4.0f, customCard.bounds.size.width - 20.0f, 34.0f);
        [resetBtn setTitle:@"Reset to Default" forState:UIControlStateNormal];
        [resetBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        resetBtn.titleLabel.font = [UIFont systemFontOfSize:16.0f weight:UIFontWeightSemibold];
        resetBtn.backgroundColor = [UIColor colorWithRed:0.85f green:0.4f blue:0.15f alpha:1.0f];
        resetBtn.layer.cornerRadius = 8.0f;
        [resetBtn addTarget:self action:@selector(resetLocationSettings) forControlEvents:UIControlEventTouchUpInside];
        [customCard addSubview:resetBtn];

        CGFloat customCardH = fieldY + 4.0f + 34.0f + 10.0f;
        customCard.frame = CGRectMake(pad, y, w - pad * 2.0f, customCardH);
        y += customCardH + 8.0f;
    }

    CGFloat contentH = y + 8.0f;
    self.contentScrollView.contentSize = CGSizeMake(self.contentScrollView.bounds.size.width, contentH);
    self.contentView.frame = CGRectMake(0, 0, self.contentScrollView.bounds.size.width, contentH);
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if (pickerView.tag == 5000) return 13;
    if (filteredItems) return (NSInteger)[filteredItems count];
    return (NSInteger)[availableItems count];
}

- (NSAttributedString *)pickerView:(UIPickerView *)pickerView attributedTitleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSString *title = @"";
    if (pickerView.tag == 5000) {
        if (row < (NSInteger)[presetLocationNames count])
            title = presetLocationNames[row];
    } else {
        NSArray *src = filteredItems ? filteredItems : availableItems;
        if (row < (NSInteger)[src count])
            title = src[row];
    }
    return [[NSAttributedString alloc] initWithString:title attributes:@{
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSFontAttributeName: [UIFont systemFontOfSize:13.0f weight:UIFontWeightMedium]
    }];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    if (pickerView.tag == 5000) {
        selectedPresetLocation = row;
        [self applyPresetLocationAuto];
    } else {
        NSArray *src = filteredItems ? filteredItems : availableItems;
        if (row < (NSInteger)[src count]) {
            selectedItemIndex = [availableItems indexOfObject:src[row]];
            saveSettings();
        }
    }
}

- (void)searchItemsWithTextField:(UITextField *)tf {
    NSString *text = tf.text ? [tf.text lowercaseString] : @"";
    if (text.length > 0) {
        NSMutableArray *results = [NSMutableArray array];
        for (NSString *item in availableItems) {
            if ([[item lowercaseString] rangeOfString:text].location != NSNotFound)
                [results addObject:item];
        }
        filteredItems = [results copy];
    } else {
        filteredItems = nil;
    }
    [self.itemPicker reloadAllComponents];
    [self.itemPicker selectRow:0 inComponent:0 animated:NO];
    saveSettings();
}

- (void)toggleCustomLocation:(UISwitch *)sender {
    useCustomLocation = sender.isOn;
    saveSettings();
    [self loadCurrentTab];
}

- (void)applyLocationSettings {
    UIView *firstSub = [self.contentView.subviews firstObject];
    UITextField *tfX = (UITextField *)[firstSub viewWithTag:3001];
    UITextField *tfY = (UITextField *)[firstSub viewWithTag:3002];
    UITextField *tfZ = (UITextField *)[firstSub viewWithTag:3003];
    customSpawnX = [[tfX text] floatValue];
    customSpawnY = [[tfY text] floatValue];
    customSpawnZ = [[tfZ text] floatValue];
    saveSettings();
    AudioServicesPlaySystemSound(0x5EFu);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Applied" message:@"Spawn location updated!" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyPresetLocationAuto {
    if (selectedPresetLocation >= 13) return;
    useCustomLocation = YES;
    if (selectedPresetLocation > 0) {
        Vec3 coord = presetLocationCoords[selectedPresetLocation];
        customSpawnX = coord.x;
        customSpawnY = coord.y;
        customSpawnZ = coord.z;
    }
    saveSettings();
    [self loadCurrentTab];
}

- (void)applyPresetLocation:(id)sender {
    if (selectedPresetLocation >= 13) return;
    useCustomLocation = YES;
    if (selectedPresetLocation > 0) {
        Vec3 coord = presetLocationCoords[selectedPresetLocation];
        customSpawnX = coord.x;
        customSpawnY = coord.y;
        customSpawnZ = coord.z;
    }
    saveSettings();
    AudioServicesPlaySystemSound(0x5EFu);
    [self loadCurrentTab];
    NSString *name = selectedPresetLocation < (NSInteger)[presetLocationNames count] ? presetLocationNames[selectedPresetLocation] : @"Unknown";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Applied" message:[NSString stringWithFormat:@"Location set to: %@", name] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)resetLocationSettings {
    useCustomLocation = NO;
    customSpawnX = 0.0f;
    customSpawnY = 3.0f;
    customSpawnZ = 0.0f;
    selectedPresetLocation = 0;
    saveSettings();
    AudioServicesPlaySystemSound(0x5EFu);
    [self loadCurrentTab];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset" message:@"Settings restored to default!" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateLocationFromFields {
    customSpawnX = [self floatValueFromFieldTag:3001];
    customSpawnY = [self floatValueFromFieldTag:3002];
    customSpawnZ = [self floatValueFromFieldTag:3003];
    useCustomLocation = YES;
    saveSettings();
    AudioServicesPlaySystemSound(0x5EFu);
}

- (float)floatValueFromFieldTag:(NSInteger)tag {
    UIView *field = [self.contentView viewWithTag:tag];
    if (!field) return 0.0f;
    NSString *text = [(UITextField *)field text];
    return text ? [text floatValue] : 0.0f;
}

- (void)closeMenu {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)openKeyboard {
    UIView *searchField = [self.view viewWithTag:1000];
    if (searchField) {
        if ([searchField isFirstResponder]) [searchField resignFirstResponder];
        else [searchField becomeFirstResponder];
        AudioServicesPlaySystemSound(0x5EFu);
    } else {
        AudioServicesPlaySystemSound(0x5EFu);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"No Search Field" message:@"Search field not found." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)giveBigMoney {
    giveSelfMoney(0x98967F);
    AudioServicesPlaySystemSound(0x5EFu);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Success" message:@"Added 9,999,999 money!" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)giveAllPlayersBigMoney {
    NSLog(@"[ACMod] Giving all players 9,999,999 money");
    giveAllPlayersMoney(9999999);
    AudioServicesPlaySystemSound(0x5EFu);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"💸 Success!" message:@"All players received 9,999,999 Money!" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)giveInfAmmo {
    void *player = getLocalPlayer();
    if (!player) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Error" message:@"Could not find local player" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    if (!netPlayerClass) { return; }
    void *field = il2cpp_class_get_field_from_name(netPlayerClass, "ammo");
    if (field) {
        int val = 9999;
        il2cpp_field_set_value(player, field, &val);
        AudioServicesPlaySystemSound(0x5EFu);
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Success" message:@"Infinite ammo activated!" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    } else {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Error" message:@"Could not find ammo field" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }
}

- (void)removeShopCooldown {
    void *player = getLocalPlayer();
    if (!player) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Error" message:@"Could not find local player" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    if (!netPlayerClass) return;
    void *field = il2cpp_class_get_field_from_name(netPlayerClass, "shopCooldown");
    if (!field) field = il2cpp_class_get_field_from_name(netPlayerClass, "lastBuyTime");
    if (!field) field = il2cpp_class_get_field_from_name(netPlayerClass, "buyTimer");
    if (field) {
        int val = 0;
        il2cpp_field_set_value(player, field, &val);
        AudioServicesPlaySystemSound(0x5EFu);
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Success" message:@"Shop cooldown removed!" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    } else {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Error" message:@"Could not find cooldown field" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
    }
}

- (void)openDiscord {
    NSURL *url = [NSURL URLWithString:@"https://discord.gg/3QzJmfjKSw"];
    if ([[UIApplication sharedApplication] canOpenURL:url])
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)quantityChanged:(UIStepper *)sender {
    spawnQuantity = (NSInteger)sender.value;
    self.quantityLabel.text = [NSString stringWithFormat:@"%ld", (long)spawnQuantity];
    saveSettings();
}

- (void)spawnSelectedItem {
    if (selectedItemIndex >= (NSInteger)[availableItems count]) return;
    NSString *itemName = availableItems[selectedItemIndex];
    float spawnX = getSpawnPosition();
    spawnItem(itemName, (int)spawnQuantity, spawnX, customSpawnY, customSpawnZ);
    AudioServicesPlaySystemSound(0x5EFu);
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotate {
    return YES;
}

@end

static void openMenu(id self, SEL _cmd);
static void createMenuButton(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIApplication sharedApplication].windows firstObject];
        if (!window) return;
        if (menuButton) [menuButton removeFromSuperview];
        menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
        menuButton.frame = CGRectMake(20.0f, 80.0f, 60.0f, 36.0f);
        [menuButton setTitle:@"=XD=" forState:UIControlStateNormal];
        [menuButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        menuButton.titleLabel.font = [UIFont systemFontOfSize:17.0f weight:UIFontWeightBold];

        CAGradientLayer *grad = [CAGradientLayer layer];
        grad.frame = menuButton.bounds;
        grad.colors = @[
            (id)[[UIColor colorWithRed:0.55f green:0.15f blue:0.8f alpha:1.0f] CGColor],
            (id)[[UIColor colorWithRed:0.3f green:0.05f blue:0.55f alpha:1.0f] CGColor]
        ];
        grad.startPoint = CGPointMake(0.0f, 0.0f);
        grad.endPoint = CGPointMake(0.0f, 1.0f);
        grad.cornerRadius = 12.0f;
        [menuButton.layer insertSublayer:grad atIndex:0];

        menuButton.layer.cornerRadius = 12.0f;
        menuButton.layer.borderWidth = 1.5f;
        menuButton.layer.borderColor = [[UIColor colorWithWhite:0.85f alpha:0.6f] CGColor];

        [menuButton addTarget:[NSObject class] action:@selector(menuButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        class_addMethod([NSObject class], @selector(menuButtonTapped), (IMP)openMenu, "v@:");
        [window addSubview:menuButton];
    });
}

static void openMenu(id self, SEL _cmd) {
    if (!menuController)
        menuController = [[ModMenuController alloc] init];
    loadSettings();
    UIViewController *root = [[[[UIApplication sharedApplication] windows] firstObject] rootViewController];
    if (root) [root presentViewController:menuController animated:YES completion:nil];
}

__attribute__((constructor))
static void mod_init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (initializeIL2CPP()) {
            initializeGameClasses();
            initializeLists();
            presetLocationNames = @[
                @"Custom Input", @"Spawn", @"Forest", @"Mountain",
                @"Beach", @"Cave", @"Village", @"Ruins",
                @"River", @"Swamp", @"Desert", @"Tundra", @"Sky"
            ];
            for (int i = 0; i < 13; i++) presetLocationCoords[i] = (Vec3){0.0f, 3.0f, 0.0f};
        }
        createMenuButton();
    });
}
