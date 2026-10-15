#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs `block` and returns the Objective-C exception it raised, or nil.
/// Swift cannot catch these, and MapLibre raises them for an invalid filter.
NSException *_Nullable MapLibreGLCatchException(NS_NOESCAPE void (^block)(void));

NS_ASSUME_NONNULL_END
