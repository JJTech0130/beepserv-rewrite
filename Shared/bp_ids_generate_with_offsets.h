#ifndef BP_IDS_GENERATE_WITH_OFFSETS_H
#define BP_IDS_GENERATE_WITH_OFFSETS_H

#import <Foundation/Foundation.h>

NSString * __nonnull patched_ids_path();
NSData * __nullable validation_data_from_offsets(NSError * __nullable * __nullable error);

#endif
