//
//  BackgroundLocationTrackerObjC.m
//  teeeest
//
//  Created by Dmytro Chapovskyi on 07.04.2020.
//  Copyright © 2020 Dmytro Chapovskyi. All rights reserved.
//

#import "BackgroundLocationTrackerObjC.h"
#import "teeeest-Swift.h"

@implementation BackgroundLocationTrackerObjC

+ (void)startWithActionMinimumInterval:(NSTimeInterval)interval url:(NSURL *)url httpHeaders:(NSDictionary<NSString *,NSString *> *)httpHeaders {
	[BackgroundLocationTracker.shared startWithActionMinimumInterval:interval url:url httpHeaders:httpHeaders];	
}

+ (void)stop {
	[BackgroundLocationTracker.shared stop];
}

@end
