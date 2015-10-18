#import "Global.h"
#import <libopener/HBLibOpener.h>
#import <version.h>

@import CoreLocation;
@import MapKit;

@interface CLPlacemark (wtf)

@property (nonatomic, readonly, copy) CLLocation *location;

@end

NSString *HBMOMakeQuery(MKMapItem *mapItem) {
	if (mapItem.isCurrentLocation) {
		/*
		 if the saddr arg is empty, then google maps uses the current location
		*/

		return @"";
	} else if (mapItem.placemark.addressDictionary) {
		NSDictionary *info = mapItem.placemark.addressDictionary;
		return PERCENT_ENCODE(([[NSString stringWithFormat:@"%@ %@ %@ %@ %@", info[@"Street"] ?: @"", info[@"City"] ?: @"", info[@"State"] ?: @"", info[@"ZIP"] ?: @"", info[@"CountryCode"] ?: @""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]));
	} else {
		CLLocationCoordinate2D coord = mapItem.placemark.location.coordinate;
		return PERCENT_ENCODE(([NSString stringWithFormat:@"%f,%f", coord.latitude, coord.longitude]));
	}
}

inline BOOL isEnabled() {
	return [[HBLibOpener sharedInstance] handlerIsEnabled:kHBMOHandlerIdentifier] && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"comgooglemaps://"]];
}

#pragma mark - MapKit hooks

%group MapKit
%hook MKMapItem

+ (NSURL *)urlForMapItems:(NSArray *)items options:(id)options {
	if (!isEnabled() || items.count < 1) {
		return %orig;
	} else if (items.count == 1) {
		return [NSURL URLWithString:[@"comgooglemaps://?q=" stringByAppendingString:HBMOMakeQuery(items[0])]];
	} else {
		return [NSURL URLWithString:[NSString stringWithFormat:@"comgooglemaps://?saddr=%@&daddr=%@", HBMOMakeQuery(items[0]), HBMOMakeQuery(items[1])]];
	}
}

%end
%end

#pragma mark - NSURL hooks

%hook NSURL

+ (NSURL *)mapsURLWithSourceAddress:(NSString *)source destinationAddress:(NSString *)destination {
	return isEnabled()
		? [NSURL URLWithString:[NSString stringWithFormat:@"comgooglemaps://?saddr=%@&daddr=%@", PERCENT_ENCODE(source), PERCENT_ENCODE(destination)]]
		: %orig;
}

+ (NSURL *)mapsURLWithAddress:(NSString *)address {
	return isEnabled()
		? [NSURL URLWithString:[@"comgooglemaps://?q=" stringByAppendingString:PERCENT_ENCODE(address)]]
		: %orig;
}

+ (NSURL *)mapsURLWithQuery:(NSString *)query {
	return isEnabled()
		? [NSURL URLWithString:[@"comgooglemaps://?q=" stringByAppendingString:PERCENT_ENCODE(query)]]
		: %orig;
}

%end

#pragma mark - Init function

/*
 to shut up a logos error which complains when there's multiple %inits for
 the same thing
*/

inline void initMapKitHooks() {
	%init(MapKit);
}

#pragma mark - Constructor

%ctor {
	%init;

	/*
	 if MapKit is loaded into this process, we want to initialise our MapKit
	 hooks. if not, we need to listen for a bundle load notification in case of
	 the chance that the app late loads it
	*/

	NSBundle *bundle = [NSBundle bundleWithIdentifier:@"com.apple.MapKit"];

	if (bundle.isLoaded) {
		initMapKitHooks();
	} else if (IS_IOS_OR_NEWER(iOS_7_0) && !IS_IOS_OR_NEWER(iOS_9_0)) {
		/*
		 this causes freezes in some apps on iOS 6. rather than supporting old
		 versions everyone should really stop using already, only do this for
		 iOS 7+

		 … this is additionally broken on iOS 9, so disabling this for now.
		 probably only worked by complete luck on iOS 8?
		*/

		[[NSNotificationCenter defaultCenter] addObserverForName:NSBundleDidLoadNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
			if (notification.object == bundle) {
				initMapKitHooks();
			}
		}];
	}
}
