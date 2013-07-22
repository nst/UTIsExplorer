//
//  main.m
//  UTIsExplorer
//
//  Created by Nicolas Seriot on 3/3/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "UTIsExplorer.h"

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        
        [NSApplication sharedApplication];

        UTIsExplorer *utisExplorer = [[UTIsExplorer alloc] init];

        [utisExplorer lookForUTIs:^(NSArray *UTIs) {
            //NSLog(@"-- UTIs %@", UTIs);
        
            NSString *s = [utisExplorer graphvizDescription];
            
			NSString * const graphFileName = @"utis_graph";
			NSString * const graphFileExtension = @"dot";
            NSString *path =  [[[[NSBundle mainBundle] bundlePath]
								stringByAppendingPathComponent:graphFileName]
							   stringByAppendingPathExtension:graphFileExtension];
            
            NSError *error = nil;
            BOOL success = [s writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
            if(success) {
                NSLog(@"-- wrote file %@", path);
            } else {
                NSLog(@"-- error: %@", error);
            }

            [[NSApplication sharedApplication] terminate:nil];

        }];
        
        [utisExplorer release];

        [NSApp run];
    }
    return 0;
}

