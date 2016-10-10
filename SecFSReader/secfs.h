//
//  secfs.h
//  SecFSExample
//
//  Created by David Wagner on 10/10/2016.
//  Copyright © 2016 David Wagner. All rights reserved.
//

#ifndef secfs_h
#define secfs_h

#include <stdint.h>
#include <stdbool.h>

typedef struct secfs_filesystem_t {
    uint64_t         magic;
    uint64_t         num_files;
    uint64_t const * file_byte_lengths;
    uint64_t const * file_data_offset;
    uint8_t  const * data;
} secfs_filesystem_t;

extern const int64_t secfs_error_failed_to_open_section;

secfs_filesystem_t secfs_open(const char *segment_name, const char *section_name);
void secfs_close(secfs_filesystem_t *fs);
bool secfs_fs_is_valid(const secfs_filesystem_t *fs);

uint64_t secfs_num_files(const secfs_filesystem_t *fs);
uint64_t secfs_file_length(const secfs_filesystem_t *fs, uint64_t file_index);
const uint8_t* secfs_file_data(const secfs_filesystem_t *fs, uint64_t file_index);

#endif /* secfs_h */
