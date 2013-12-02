#include <iostream>
#include <vector>
#include <fstream>
#include <CoreFoundation/CoreFoundation.h>

#import <Foundation/NSAutoReleasePool.h>
#import <Foundation/NSString.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSRegularExpression.h>
#import <CoreTelephony/CTCallCenter.h>
#import <CoreTelephony/CoreTelephonyDefines.h>

// -----------------------------------------------------------------------------
// Core Telephony function declarations
// -----------------------------------------------------------------------------

CORETELEPHONY_EXTERN NSString *CTCallCopyAddress(void*, CTCall*);
CORETELEPHONY_EXTERN void *CTCallDisconnect(CTCall*);
CORETELEPHONY_EXTERN id CTTelephonyCenterGetDefault();
CORETELEPHONY_EXTERN void CTTelephonyCenterAddObserver(id, id, CFNotificationCallback, NSString*,
	void*, int);

// -----------------------------------------------------------------------------
// callblocker
// -----------------------------------------------------------------------------

static std::vector<NSRegularExpression*> blocklist;

static void load_blocklist();
static bool is_blocked(NSString *caller);
static void callback(CFNotificationCenterRef center, void *observer, CFStringRef name,
	const void *object, CFDictionaryRef userInfo);

int main()
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	id ct = CTTelephonyCenterGetDefault();

	CTTelephonyCenterAddObserver(ct, NULL, callback, NULL, NULL,
		CFNotificationSuspensionBehaviorDeliverImmediately);

	load_blocklist();

	[[NSRunLoop currentRunLoop] run];

	[pool drain];
	[pool release];

	return 0;
}

void load_blocklist()
{
	std::ifstream file("blocklist");
	std::string line;

	while (std::getline(file, line, '\n'))
	{
		if (line.size() > 0 && line[line.size() - 1] == '\r')
			line.resize(line.size() - 1);

		if (line.size() == 0)
			continue;

		NSError *error = NULL;
		NSString *pattern = [NSString stringWithUTF8String: line.c_str()];

		NSRegularExpression *regex = [NSRegularExpression
			regularExpressionWithPattern: pattern
			options: 0
			error: &error
		];

		if (error)
		{
			std::cerr << "Error initializing regular expression: " << line << std::endl;
		}
		else
		{
			[regex retain];
			blocklist.push_back(regex);
		}
	}
}

bool is_blocked(NSString *caller)
{
	for (int i = 0; i < (int)blocklist.size(); i++)
	{
		NSRegularExpression *regex = blocklist[i];

		NSUInteger n = [regex numberOfMatchesInString: caller
			options: 0
			range: NSMakeRange(0, [caller length])
		];

		if (n > 0)
			return true;
	}

	return false;
}

void callback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object,
	CFDictionaryRef userInfo)
{
	NSString *notifyname = (NSString*)name;

	if ([notifyname isEqualToString: @"kCTCallIdentificationChangeNotification"])
	{
		NSDictionary *info = (NSDictionary*)userInfo;

		if ([[[info objectForKey:@"kCTCallStatus"] stringValue] isEqualToString: @"4"])
		{
			CTCall *call = (CTCall*)[info objectForKey: @"kCTCall"];
			NSString *caller = CTCallCopyAddress(NULL, call);
			
			if (caller == nil)
				caller = @"0";

			if (is_blocked(caller))
			{
				CTCallDisconnect(call);
				std::cout << "Blocked number " << [caller UTF8String] << std::endl;
			}
		}
	}
}
