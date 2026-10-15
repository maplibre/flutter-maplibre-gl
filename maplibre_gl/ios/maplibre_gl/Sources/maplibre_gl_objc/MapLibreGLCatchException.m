#import "MapLibreGLCatchException.h"

NSException *_Nullable MapLibreGLCatchException(NS_NOESCAPE void (^block)(void)) {
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        return exception;
    }
}
