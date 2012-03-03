//
//  UTIsExplorer.m
//  SpotLook
//
//  Created by Nicolas Seriot on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "UTIsExplorer.h"
#import <CoreServices/CoreServices.h>

@implementation UTIsExplorer

- (id)init {
    self = [super init];
    
    parentsForUTIs = [[NSMutableDictionary alloc] init];
    
    return self;
}

- (void)dealloc {
    [parentsForUTIs release];
    [super dealloc];
}

- (NSString *)graphvizDescription {
    
    NSMutableString *ms = [NSMutableString stringWithString:@"digraph G {\n"];
    [ms appendString:@"    node [shape=box]\n"];
    [ms appendString:@"    graph [rankdir=LR]\n\n"];
    
    NSArray *sortedKeys = [[parentsForUTIs allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *s1, NSString *s2) {
        return [s1 compare:s2];
    }];
    
    for(NSString *key in sortedKeys) {
        NSSet *parents = [parentsForUTIs valueForKey:key];

        for(NSString *p in parents) {
            [ms appendFormat:@"    \"%@\" -> \"%@\"\n", key, p];        
        }
    }
    
    [ms appendString:@"}\n"];
    
    return ms;
}

- (void)addParentsForUTI:(NSString *)UTI {
    
    if([parentsForUTIs valueForKey:UTI] != nil) return;
    
    NSDictionary *d = (NSDictionary *)UTTypeCopyDeclaration((CFStringRef)UTI);
    id o = [d valueForKey:(NSString *)kUTTypeConformsToKey];
    
    NSMutableSet *set = [NSMutableSet set];

    if(o == nil) {
        [set addObjectsFromArray:[NSArray array]];
    } else if([o isKindOfClass:[NSString class]]) {
        [set addObject:o];
    } else if ([o isKindOfClass:[NSArray class]]) {
        [set addObjectsFromArray:o];        
    } else {
        NSAssert(NO, @"-- bad class: %@", o);
    }
    
    [parentsForUTIs setValue:set forKey:UTI];
}

- (NSDictionary *)buildUTIsDictionary {
    
    __block NSMutableSet *missingParents = [NSMutableSet setWithArray:[[self class] systemUTIs]];
    
    while([missingParents count] > 0) {

        for(NSString *p in missingParents) {
            [self addParentsForUTI:p];
        }
        
        [missingParents removeAllObjects];
        
        [parentsForUTIs enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSSet *parents = (NSSet *)obj;
            
            for(NSString *p in parents) {
                if([parentsForUTIs valueForKey:p] == nil) {
                    [missingParents addObject:p];
                }
            }
        }];
        
    }
        
    return parentsForUTIs;
}

+ (NSArray *)systemUTIs {
    
    NSArray *paths = [NSArray arrayWithObjects:@"/Applications/", @"/Library/Spotlight/", @"/System/Library/Spotlight/", nil];

    NSMutableSet *set = [NSMutableSet set];
    
    for(NSString *path in paths) {
        NSArray *UTIs = [self UTIsFromMDImportersAtRootPath:path];
        [set addObjectsFromArray:UTIs];
    }
    
    return [set allObjects];
}

+ (NSArray *)mdImportersBundlesPathsFromRootPath:(NSString *)rootPath {

    //return [NSArray arrayWithObject:@"/System/Library/Spotlight/Mail.mdimporter"];
    
    NSFileManager *localFileManager = [[NSFileManager alloc] init];
        
    NSMutableArray *ma = [NSMutableArray array];
    
    NSDirectoryEnumerator *enumerator = [localFileManager enumeratorAtPath:rootPath];

    NSString *path = nil;
    while(path = [enumerator nextObject]) {
        if([[path pathExtension] isEqualToString:@"mdimporter"]) {
            NSString *bundlePath = [rootPath stringByAppendingPathComponent:path];
            NSLog(@"-- found %@", bundlePath);
            [ma addObject:bundlePath];
        }
    }
    
    return ma;
}

+ (NSArray *)UTISInBundleAtPath:(NSString *)path {
    NSBundle *bundle = [NSBundle bundleWithPath:path];
    NSDictionary *infoDictionary = [bundle infoDictionary];
    
    NSDictionary *CFBundleDocumentTypes = [infoDictionary valueForKey:@"CFBundleDocumentTypes"];
    NSArray *LSItemContentTypes = [CFBundleDocumentTypes valueForKey:@"LSItemContentTypes"];

    if(LSItemContentTypes == nil) {
        return [NSArray array];
    }
    
    NSAssert([LSItemContentTypes isKindOfClass:[NSArray class]], @"-- bad class: %@", [LSItemContentTypes class]);
    
    NSArray *UTIs = [LSItemContentTypes lastObject];
    
    NSAssert([UTIs isKindOfClass:[NSArray class]], @"-- bad class: %@", [LSItemContentTypes class]);
    
    return UTIs;
}

+ (NSArray *)UTIsFromMDImportersAtRootPath:(NSString *)path {
    
    NSLog(@"-- scanning path: %@", path);
    
    NSArray *paths = [self mdImportersBundlesPathsFromRootPath:path];
        
    NSMutableSet *set = [NSMutableSet set];
    
    for(NSString *path in paths) {
        NSArray *UTIs = [self UTISInBundleAtPath:path];
        [set addObjectsFromArray:UTIs];
    }
    
    return [set allObjects];
}

@end
