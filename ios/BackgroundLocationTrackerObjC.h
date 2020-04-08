//
//  BackgroundLocationTrackerObjC.h
//  teeeest
//
//  Created by Dmytro Chapovskyi on 07.04.2020.
//  Copyright © 2020 Dmytro Chapovskyi. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BackgroundLocationTrackerObjC : NSObject

/**
Call the function whenever necessary; to support background tracking you must call `continueIfAppropriate()` on every app launch - see the doc.
*/
+ (void)startWithActionMinimumInterval:(NSTimeInterval)interval url:(NSURL *)url httpHeaders:(NSDictionary *)httpHeaders;

/**
Call this method in `application: didFinishLaunchingWithOptions:` to enable background location updates
If `start(...)` hasn't been called before, nothing will happen.
*/
+ (void)continueIfAppropriate;

+ (void)stop;



@end

NS_ASSUME_NONNULL_END
