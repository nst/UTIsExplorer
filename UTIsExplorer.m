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

- (void)searchForMDImporters:(void (^) (NSArray *mdImporterPaths))terminationBlock {
    NSMetadataQuery *query = [[NSMetadataQuery alloc] init];
    query.predicate = [NSPredicate predicateWithFormat:@"kMDItemContentTypeTree == 'com.apple.metadata-importer'"];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:NSMetadataQueryDidFinishGatheringNotification object:query queue:nil usingBlock:^(NSNotification *note) {
        
        [query stopQuery];
        
        NSOperationQueue *oq = [[[NSOperationQueue alloc] init] autorelease];
        
        [oq addOperationWithBlock:^{
            NSMutableArray *mdImporterPaths = [NSMutableArray array];
            
            for(NSUInteger i = 0; i < [query resultCount]; i++) {
                
                NSMetadataItem *mdItem = [query resultAtIndex:i];
                
                NSString *path = [mdItem valueForAttribute:(NSString *)kMDItemPath];
                [mdImporterPaths addObject:path];
            }
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                terminationBlock(mdImporterPaths);
            }];
        }];
        
    }];
    
    [query startQuery];
}

- (void)searchForApplicationsMDImporters:(void (^) (NSArray *mdImporterPaths))terminationBlock {
    NSMetadataQuery *query = [[NSMetadataQuery alloc] init];
    query.predicate = [NSPredicate predicateWithFormat:@"kMDItemContentTypeTree == 'com.apple.application-bundle'"];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:NSMetadataQueryDidFinishGatheringNotification object:query queue:nil usingBlock:^(NSNotification *note) {
        
        [query stopQuery];
        
        NSOperationQueue *oq = [[[NSOperationQueue alloc] init] autorelease];
        
        [oq addOperationWithBlock:^{
            NSFileManager *fm = [[NSFileManager alloc] init];
            
            NSMutableArray *mdImporterPaths = [NSMutableArray array];
            
            for(NSUInteger i = 0; i < [query resultCount]; i++) {
                
                NSMetadataItem *mdItem = [query resultAtIndex:i];
                
                NSString *path = [mdItem valueForAttribute:(NSString *)kMDItemPath];
                NSString *spotlightDirectory = [path stringByAppendingPathComponent:@"/Contents/Library/Spotlight/"];
                NSArray *importers = [fm contentsOfDirectoryAtPath:spotlightDirectory error:nil];
                
                for(NSString *name in importers) {
                    if([[name pathExtension] isEqualToString:@"mdimporter"] == NO) continue;
                    
                    NSString *mdImporterPath = [spotlightDirectory stringByAppendingPathComponent:name];
                    
                    [mdImporterPaths addObject:mdImporterPath];
                }
            }
            
            [fm release];
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                terminationBlock(mdImporterPaths);
            }];
            
        }];
        
    }];
    
    [query startQuery];
}

- (NSArray *)allUTIs {
    NSMutableSet *set = [NSMutableSet set];
    
    [parentsForUTIs enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSSet *parents = (NSSet *)obj;
        
        [set addObject:key];
        [set unionSet:parents];
    }];
    
    NSArray *UTIs = [set allObjects];
    
    NSArray *sortedUTIs = [UTIs sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];
    
    return sortedUTIs;
}

- (void)lookForUTIs:(void (^) (NSArray *UTIs))successBlock {
    
    [self searchForMDImporters:^(NSArray *mdImporters) {
        
        [self searchForApplicationsMDImporters:^(NSArray *appMDImporters) {
            
            NSArray *importers = [mdImporters arrayByAddingObjectsFromArray:appMDImporters];
            
            for(NSString *path in importers) {
                
                NSArray *UTIs = [[self class] UTISInBundleAtPath:path];
                
                for(NSString *uti in UTIs) {
                    [self addParentsForUTI:uti];
                }
                
            }
            
            [self addAllParents];
            
            successBlock([self allUTIs]);            
        }];
        
    }];
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
    
    [d release];
    
    [parentsForUTIs setValue:set forKey:UTI];
}

- (void)addAllParents {
    
    NSMutableArray *missingParents = [NSMutableSet setWithArray:[parentsForUTIs allKeys]];
    
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

@end
