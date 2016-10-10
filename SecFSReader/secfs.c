//
//  secfs.c
//  SecFSExample
//
//  Created by David Wagner on 10/10/2016.
//  Copyright © 2016 David Wagner. All rights reserved.
//

#include "secfs.h"
#include <mach-o/getsect.h>
#include <mach-o/ldsyms.h>

const uint64_t kMagic = 0xDEC0DEC0FFEEFACELL;

const int64_t secfs_error_failed_to_open_section = 1;

//typedef struct secfs_filesystem_t {
//    uint64_t         magic;
//    uint64_t         num_files;
//    uint64_t const * file_byte_lengths;
//    uint64_t const * file_data_offset;
//    uint8_t  const * data;
//} secfs_filesystem_t;

secfs_filesystem_t secfs_open(const char *segment_name, const char *section_name) {
    unsigned long size = 0;
    uint8_t *section_data_ptr = getsectiondata(&_mh_execute_header, segment_name, section_name, &size);
    
    secfs_filesystem_t fs = {0};
    if (NULL == section_data_ptr || size == 0) {
        fs.magic = secfs_error_failed_to_open_section;
    } else {
        uint64_t *item_ptr = (uint64_t *)section_data_ptr;
        fs.num_files = *item_ptr;
        item_ptr += 1;
        
        fs.file_byte_lengths = item_ptr;
        item_ptr += fs.num_files;
        
        fs.file_data_offset = item_ptr;
        item_ptr += fs.num_files;
        
        fs.data = (uint8_t *)item_ptr;
        
        fs.magic = kMagic;
    }

    return fs;
}

bool secfs_fs_is_valid(const secfs_filesystem_t *fs) {
    return fs && fs->magic == kMagic;
}

void secfs_close(secfs_filesystem_t *fs) {
#warning TODO
    if (fs) {
        fs->magic = 0LL;
    }
}

uint64_t secfs_num_files(const secfs_filesystem_t *fs) {
    if (fs && fs->magic == kMagic) {
        return fs->num_files;
    } else {
        return 0;
    }
}

uint64_t secfs_file_length(const secfs_filesystem_t *fs, uint64_t file_index) {
    if (fs && fs->magic == kMagic && file_index < fs->num_files) {
        return fs->file_byte_lengths[file_index];
    } else {
        return 0;
    }
}

const uint8_t* secfs_file_data(const secfs_filesystem_t *fs, uint64_t file_index) {
    if (fs && fs->magic == kMagic && file_index < fs->num_files) {
        return fs->data + fs->file_data_offset[file_index];
    } else {
        return NULL;
    }
}

