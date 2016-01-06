//
//  TYDKSynxPlugin.m
//  TYDKSynxPlugin
//
//  Created by 李浩然 on 1/6/16.
//  Copyright © 2016 tydic-lhr. All rights reserved.
//

#import "TYDKSynxPlugin.h"
#import "CCPDocumentationManager.h"
#import "CCPPathResolver.h"
#import "CCPProject.h"
#import "CCPShellRunner.h"
#import "CCPWorkspaceManager.h"
#import "CCPProject+SynxProject.h"

static NSString* const GEM_EXECUTABLE = @"gem";
static NSString* const GEM_PATH_DEFAULT = @"/usr/bin";
static NSString* const GEM_PATH_KEY = @"GEM_PATH_KEY";
static NSString* const OPEN_EXECUTABLE = @"/usr/bin/open";
static NSString* const SYNX_EXECUTABLE = @"synx";
static NSString* const RESOLVER_ERROR_FORMAT = @"Resolved command path for \"%@\" is invalid.\n\nExpanded GEM_PATH: %@";
static NSString* const RESOLVER_TITLE_TEXT = @"The command path could not be resolved";
static NSString* const XAR_EXECUTABLE = @"/usr/bin/xar";

@interface TYDKSynxPlugin()

@property (nonatomic, strong, readwrite) NSBundle *bundle;

@property (nonatomic, strong) NSMenuItem *synxXcodeprojItem;

@end

@implementation TYDKSynxPlugin





+ (instancetype)sharedPlugin
{
    return sharedPlugin;
}

- (id)initWithBundle:(NSBundle *)plugin
{
    if (self = [super init]) {
        // reference to plugin's bundle, for resource access
        self.bundle = plugin;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didApplicationFinishLaunchingNotification:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
    }
    return self;
}

- (void)didApplicationFinishLaunchingNotification:(NSNotification*)noti
{
    //removeObserver
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSApplicationDidFinishLaunchingNotification object:nil];
    
    // Create menu items, initialize UI, etc.
    // Sample Menu Item:
    [self addMenuItems];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Menu

- (BOOL)validateMenuItem:(NSMenuItem*)menuItem
{
    if ([menuItem isEqual:self.synxXcodeprojItem]) {
        return [[CCPProject projectForKeyWindow] hasProject];
    }
    
    return YES;
}

- (void)addMenuItems
{
    NSMenuItem *topMenuItem = [[NSApp mainMenu] itemWithTitle:@"Product"];
    if (topMenuItem) {
        [[topMenuItem submenu] addItem:[NSMenuItem separatorItem]];
        NSMenuItem *synxMenuItem = [[NSMenuItem alloc] initWithTitle:@"Synx" action:@selector(doMenuAction) keyEquivalent:@""];
        
        synxMenuItem.submenu = [[NSMenu alloc] initWithTitle:@"Synx"];
        //[synxMenuItem setKeyEquivalentModifierMask:NSAlphaShiftKeyMask | NSControlKeyMask];
        
        self.synxXcodeprojItem = [[NSMenuItem alloc] initWithTitle:@"Synx Project"
                                                            action:@selector(integrateSynx)
                                                     keyEquivalent:@""];
        
        [self.synxXcodeprojItem setTarget:self];
        
        
        [synxMenuItem setTarget:self];
        [[synxMenuItem submenu] addItem:self.synxXcodeprojItem];
        
        [[topMenuItem submenu] addItem:synxMenuItem];
        
        
    }

}
// Sample Action, for menu item:
- (void)doMenuAction
{
//    NSAlert *alert = [[NSAlert alloc] init];
//    [alert setMessageText:@"Hello, World"];
//    [alert runModal];
}

- (void)integrateSynx {
    
    NSString* const CPFallbackPodPath = @"/usr/local/bin";
    CCPProject* project = [CCPProject projectForKeyWindow];
    BOOL isDir;
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:project.workspacePath isDirectory:&isDir];
    NSString* expandedGemPath = [CCPPathResolver stringByAdjustingGemPathForEnvironment:[self gemPath]];
    NSString* resolvedCommand = [CCPPathResolver resolveCommand:SYNX_EXECUTABLE forPath:expandedGemPath];
    
    if (resolvedCommand == nil) {
        resolvedCommand = [CCPPathResolver resolveCommand:SYNX_EXECUTABLE forPath:CPFallbackPodPath];
        if (resolvedCommand == nil) {
            NSAlert* alert = [[NSAlert alloc] init];
            [alert setAlertStyle:NSCriticalAlertStyle];
            [alert setMessageText:RESOLVER_TITLE_TEXT];
            [alert setInformativeText:[NSString stringWithFormat:RESOLVER_ERROR_FORMAT, SYNX_EXECUTABLE, expandedGemPath]];
            [alert runModal];
            return;
        }
    }
    
    [CCPShellRunner runShellCommand:resolvedCommand
                           withArgs:@[@"--no-color" ,[project projectPath]]
                          directory:[CCPWorkspaceManager currentWorkspaceDirectoryPath]
                         completion:^(NSTask* t) {
//                             if ([self shouldInstallDocsForPods])
//                                 [self installOrUpdateDocSetsForPods];
                             // Only prompt if this is the first time
                             if (!fileExists || !isDir) {
                                 dispatch_async(dispatch_get_main_queue(), ^{
//                                     [self showReopenWorkspaceMessageForProject:project];
                                     
                                     NSAlert *alert = [[NSAlert alloc] init];
                                     [alert setMessageText:@"成功"];
                                     [alert runModal];
                                     
                                     
                                 });
                             }
                         }];

}



#pragma mark - Preferences



- (void)updateGemPath:(NSString*)string
{
    if (string.length == 0) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:GEM_PATH_KEY];
    }
    else {
        [[NSUserDefaults standardUserDefaults] setObject:string forKey:GEM_PATH_KEY];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self loadCustomGemPath];
}

- (void)loadCustomGemPath
{
    NSString* newPath = [CCPPathResolver stringByAdjustingGemPathForEnvironment:[self customGemPath]];
    if (newPath.length > 0) {
        char* oldPath = getenv("PATH");
        newPath = [NSString stringWithFormat:@"%@:%s", newPath, oldPath];
        setenv("PATH", [newPath UTF8String], 1);
    }
}

- (NSString*)customGemPath
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:GEM_PATH_KEY];
}

- (NSString*)gemPath
{
    NSString* path = [self customGemPath];
    if (path.length == 0) {
        path = GEM_PATH_DEFAULT;
    }
    return path;
}


@end