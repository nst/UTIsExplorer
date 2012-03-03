//
//  main.m
//  UTIsExplorer
//
//  Created by Nicolas Seriot on 3/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UTIsExplorer.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        UTIsExplorer *utisExplorer = [[UTIsExplorer alloc] init];
        
        [utisExplorer buildUTIsDictionary];
        
        NSString *s = [utisExplorer graphvizDescription];
        
        NSString *path = [@"~/Desktop/utis_graph.dot" stringByExpandingTildeInPath];
        
        NSError *error = nil;
        BOOL success = [s writeToFile:path atomically:YES encoding:NSISOLatin1StringEncoding error:&error];
        if(success) {
            NSLog(@"-- wrote file %@", path);
        } else {
            NSLog(@"-- error: %@", error);
        }
        
        [utisExplorer release];
        
    }
    return 0;
}

