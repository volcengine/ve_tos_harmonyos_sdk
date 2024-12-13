/*
 * Copyright (c) 2024 Beijing Volcano Engine Technology Ltd and/or its affiliates
 *  SPDX-License-Identifier: MIT
 */

import { Headers } from './common';
import { AzRedundancyType, BucketType, StorageClassType } from './enum';

export interface ListBucketsRequestHeaders extends Headers {
  ['x-tos-project-name']?: string;
}

export interface HeadBucketResponseHeaders extends Headers {
  ['x-tos-bucket-region']: string;
  ['x-tos-storage-class']: StorageClassType;
  ['x-tos-project-name']?: string;
  ['x-tos-az-redundancy']: AzRedundancyType;
  ['x-tos-bucket-type']?: BucketType,
}

export interface HeadObjectResponseHeaders extends Headers {
  'content-length': string;
  'last-modified': string;
  'content-md5': string;
  etag: string;
  'x-tos-object-type'?: 'Appendable' | 'Symlink';
  'x-tos-delete-marker'?: string;
  'x-tos-server-side-encryption-customer-algorithm'?: string;
  'x-tos-server-side-encryption-customer-key-md5'?: string;
  'x-tos-version-id'?: string;
  'x-tos-website-redirect-location'?: string;
  'x-tos-hash-crc64ecma'?: string;
  'x-tos-storage-class': StorageClassType;
  'x-tos-server-side-encryption'?: string;
  //'x-tos-replication-status'?: ReplicationStatusType;
  'x-tos-symlink-target-size'?: string;
}