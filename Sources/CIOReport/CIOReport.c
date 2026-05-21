// The IOReport bridge target only carries declarations and link-time
// references to /System/Library/PrivateFrameworks/IOReport.framework.
// SwiftPM requires at least one translation unit for a C target; this
// file exists to satisfy that requirement and intentionally adds nothing
// else.

#include "CIOReport.h"
