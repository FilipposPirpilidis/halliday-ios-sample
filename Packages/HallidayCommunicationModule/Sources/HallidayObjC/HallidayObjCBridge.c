
#include "HallidayObjCBridge.h"
#include <opus/opus.h>

int halliday_opus_link_anchor(void) {
    return opus_get_version_string() != 0;
}
