// Declarations for the macOS IOReport SPI used by PlumageBar's GPU reader.
// On macOS 26+, IOReport ships as /usr/lib/libIOReport.dylib (it was a
// PrivateFramework on earlier releases). Headers are not in the public SDK;
// we declare the minimal subset we use so the Swift side has type-checked
// signatures.
//
// `IOReportSubscriptionRef` is intentionally typedef'd as `CFTypeRef` so
// Swift's CoreFoundation bridge gives us ARC-managed lifetime: when the
// last reference goes out of scope, CFRelease balances the +1 retain from
// `IOReportCreateSubscription`. libIOReport.dylib on macOS 26 does NOT
// export an `IOReportFreeSubscription` symbol; CF retain/release is the
// only public release path.
//
// All declarations live inside CF_IMPLICIT_BRIDGING_ENABLED so Swift sees
// `CFString` / `CFDictionary` directly instead of `Unmanaged<...>`. Functions
// that return owned +1 references are marked with CF_RETURNS_RETAINED;
// everything else follows the default Get rule (caller does not own).
//
// Apple may change or remove this SPI without warning. Every call site in
// Swift must treat nil / missing keys / unexpected dictionary shapes as a
// soft failure (return nil, log once) rather than crashing.

#ifndef CIOREPORT_H
#define CIOREPORT_H

#include <CoreFoundation/CoreFoundation.h>

#if defined(__cplusplus)
extern "C" {
#endif

typedef CFTypeRef IOReportSubscriptionRef;

typedef int (^IOReportSampleCallbackBlock)(CFDictionaryRef sample);

CF_IMPLICIT_BRIDGING_ENABLED

CF_RETURNS_RETAINED
CFMutableDictionaryRef IOReportCopyChannelsInGroup(
    CFStringRef group,
    CFStringRef subgroup,
    uint64_t channel_id,
    uint64_t a,
    uint64_t b
);

// `outSubbedChannels` receives a +1 reference that the caller must release.
// The CF retain attribute can't ride on an out-pointer through the Swift
// bridge, so callers receive `Unmanaged<CFMutableDictionary>?` here and call
// `.takeRetainedValue()` to balance the retain.
IOReportSubscriptionRef IOReportCreateSubscription(
    void *a,
    CFMutableDictionaryRef desiredChannels,
    CFMutableDictionaryRef *outSubbedChannels,
    uint64_t channel_id,
    CFTypeRef b
);

CF_RETURNS_RETAINED
CFDictionaryRef IOReportCreateSamples(
    IOReportSubscriptionRef subscription,
    CFMutableDictionaryRef channels,
    CFTypeRef a
);

CF_RETURNS_RETAINED
CFDictionaryRef IOReportCreateSamplesDelta(
    CFDictionaryRef previousSample,
    CFDictionaryRef currentSample,
    CFTypeRef a
);

// The block returns 0 to continue, non-zero to stop.
void IOReportIterate(
    CFDictionaryRef samples,
    IOReportSampleCallbackBlock callback
);

// Channel metadata accessors (Get rule).
CFStringRef IOReportChannelGetGroup(CFDictionaryRef sample);
CFStringRef IOReportChannelGetSubGroup(CFDictionaryRef sample);
CFStringRef IOReportChannelGetChannelName(CFDictionaryRef sample);

// State channel accessors.
int32_t  IOReportStateGetCount(CFDictionaryRef sample);
CFStringRef IOReportStateGetNameForIndex(CFDictionaryRef sample, int32_t index);
int64_t  IOReportStateGetResidency(CFDictionaryRef sample, int32_t index);

// Simple integer channels.
int64_t  IOReportSimpleGetIntegerValue(CFDictionaryRef sample, int32_t index);

CF_IMPLICIT_BRIDGING_DISABLED

#if defined(__cplusplus)
}
#endif

#endif  // CIOREPORT_H
