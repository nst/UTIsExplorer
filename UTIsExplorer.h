//
//  UTIsExplorer.h
//  SpotLook
//
//  Created by Nicolas Seriot on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UTIsExplorer : NSObject {
    NSMutableDictionary *parentsForUTIs;
}

- (void)lookForUTIs:(void (^) (NSArray *UTIs))successBlock;

- (NSString *)graphvizDescription;

@end
